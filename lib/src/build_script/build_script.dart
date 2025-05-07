import 'dart:io';

import 'package:collection/collection.dart';
import 'package:dart_style/dart_style.dart';
import 'package:lean_builder/builder.dart';
import 'package:lean_builder/element.dart';
import 'package:lean_builder/src/asset/asset.dart';
import 'package:lean_builder/src/build_script/errors.dart';
import 'package:lean_builder/src/build_script/generator.dart';
import 'package:lean_builder/src/graph/asset_scan_manager.dart';
import 'package:lean_builder/src/graph/scan_results.dart';
import 'package:lean_builder/src/logger.dart';
import 'package:lean_builder/src/resolvers/resolver.dart';
import 'package:lean_builder/src/type/type.dart';
import 'package:path/path.dart' as p;
import 'compile.dart' as compile;
import 'files.dart';

const String _leanAnnotations = 'package:lean_builder/src/build_script/annotations.dart';
const String _leanGenerator = 'package:lean_builder/src/builder/generator/generator.dart';
const String _leanBuilders = 'package:lean_builder/src/builder/builder.dart';
const String _parsedBuilderEntry = 'package:lean_builder/src/build_script/parsed_builder_entry.dart';

String? prepareBuildScript(Set<ProcessableAsset> assets, ResolverImpl resolver) {
  final scriptFile = File(scriptOutput);

  void deleteScriptFile() {
    if (scriptFile.existsSync()) {
      scriptFile.deleteSync();
    }
  }

  bool hasChanges = false;
  for (final entry in Set.of(assets)) {
    if (entry.state == AssetState.deleted) {
      hasChanges = true;
      resolver.graph.removeAsset(entry.asset.id);
      entry.asset.safeDelete();
      assets.remove(entry);
    } else if (entry.state == AssetState.unProcessed) {
      hasChanges = true;
    }
  }

  if (!hasChanges && scriptFile.existsSync()) {
    return scriptFile.path;
  }

  /// invalidate processed assets on new build script generation
  final rootPackage = resolver.fileResolver.rootPackage;
  resolver.graph.invalidateProcessedAssetsOf(rootPackage);

  final (entries, overrides) = parseBuilderEntries(Set.of(assets.map((e) => e.asset)), resolver);
  if (entries.isEmpty) {
    deleteScriptFile();
    return null;
  }

  final withOverrides = applyOverrides(entries, overrides);

  Logger.info('Generating a new build script...');
  var script = generateBuildScript(withOverrides);
  final formatter = DartFormatter(languageVersion: DartFormatter.latestShortStyleLanguageVersion);
  script = formatter.format(script);

  if (!scriptFile.existsSync()) {
    scriptFile.createSync(recursive: true);
  }
  scriptFile.writeAsStringSync(script);

  compile.invalidateExecutable();
  return scriptFile.path;
}

List<BuilderDefinitionEntry> applyOverrides(List<BuilderDefinitionEntry> entries, List<BuilderOverride> overrides) {
  if (overrides.isEmpty) return entries;

  final finalEntries = <BuilderDefinitionEntry>[];
  for (final entry in entries) {
    final override = overrides.firstWhereOrNull((e) => e.key == entry.key);
    if (override != null) {
      finalEntries.add(entry.merge(override));
    } else {
      finalEntries.add(entry);
    }
  }

  return finalEntries;
}

(List<BuilderDefinitionEntry>, List<BuilderOverride>) parseBuilderEntries(Set<Asset> assets, ResolverImpl resolver) {
  final parsedEntries = <BuilderDefinitionEntry>[];
  final parsedOverrides = <BuilderOverride>[];
  late final leanGenTypeChecker = resolver.typeCheckerFor('LeanGenerator', _leanAnnotations);
  late final leanBuilderTypeChecker = resolver.typeCheckerFor('LeanBuilder', _leanAnnotations);
  late final leanBuilderOverrideTypeChecker = resolver.typeCheckerFor('LeanBuilderOverrides', _leanAnnotations);
  late final generatorTypeChecker = resolver.typeCheckerFor('Generator', _leanGenerator);
  late final builderTypeChecker = resolver.typeCheckerFor('Builder', _leanBuilders);
  late final builderOverrideTypeChecker = resolver.typeCheckerFor('BuilderOverride', _parsedBuilderEntry);

  for (final asset in assets) {
    final library = resolver.resolveLibrary(asset);
    for (final annotatedElement in library.annotatedWithExact(leanGenTypeChecker)) {
      final element = annotatedElement.element;
      if (element is! ClassElement) {
        throw BuildConfigError('Expected a class element for generator annotation');
      }
      final superType = element.superType;
      if (superType == null || !generatorTypeChecker.isAssignableFromType(superType)) {
        throw BuildConfigError('Expected a class that extends Generator for LeanGenerator annotation');
      }

      final constObj = annotatedElement.annotation.constant;
      if (constObj is! ConstObject) {
        throw BuildConfigError('Could not read annotation object');
      }

      final isShared = constObj.constructorName == 'shared';
      final builderType = isShared ? BuilderType.shared : BuilderType.library;
      final builderEntry = _buildEntry(asset, constObj, resolver, element, builderType);
      parsedEntries.add(builderEntry);
    }

    for (final annotatedElement in library.annotatedWithExact(leanBuilderTypeChecker)) {
      final element = annotatedElement.element;
      if (element is! ClassElement) {
        throw BuildConfigError('Expected a class element for builder annotation');
      }
      final superType = element.superType;

      if (superType == null || !builderTypeChecker.isAssignableFromType(superType)) {
        throw BuildConfigError('Expected a class that extends Builder for LeanBuilder annotation');
      }

      final constObj = annotatedElement.annotation.constant;
      if (constObj is! ConstObject) {
        throw BuildConfigError('Could not read annotation object');
      }

      final builderEntry = _buildEntry(asset, constObj, resolver, element, BuilderType.custom);
      parsedEntries.add(builderEntry);
    }

    for (final annotatedElement in library.annotatedWithExact(leanBuilderOverrideTypeChecker)) {
      final element = annotatedElement.element;
      if (element is! TopLevelVariableElement || !element.isConst) {
        throw BuildConfigError(
          'Expected a const top-level variable of type List<BuilderOverride> for LeanBuilderOverrides annotation',
        );
      }
      final constObj = element.constantValue;
      if (constObj is! ConstList) {
        throw BuildConfigError('Could not read annotation object');
      }
      final list = constObj.value;
      if (list.isEmpty) continue;
      for (final obj in list) {
        if (obj is! ConstObject || !builderOverrideTypeChecker.isExactlyType(obj.type)) {
          throw BuildConfigError('Expected a const object of type BuilderOverride as list element');
        }
        final builderOverride = BuilderOverride(
          key: obj.getString('key')!.value,
          generateFor: obj.getSet('generateFor')?.literalValue.cast<String>(),
          runsBefore: obj.getSet('runsBefore')?.literalValue.cast<String>(),
          options: obj.getMap('options')?.literalValue.cast<String, dynamic>(),
        );
        if (builderOverride.key.isEmpty) {
          throw BuildConfigError('Expected a non-empty key for BuilderOverride');
        }
        if (parsedOverrides.any((e) => e.key == builderOverride.key)) {
          throw BuildConfigError('Duplicate key found for BuilderOverride: ${builderOverride.key}');
        }
        parsedOverrides.add(builderOverride);
      }
    }
  }

  return (parsedEntries, parsedOverrides);
}

BuilderDefinitionEntry _buildEntry(
  Asset asset,
  ConstObject constObj,
  ResolverImpl resolver,
  ClassElement element,
  BuilderType builderType,
) {
  Set<String>? outputExtensions;
  if (builderType.isLibrary) {
    final extensions = constObj.getSet('outputExtensions')?.literalValue.cast<String>();
    if (extensions != null && extensions.isNotEmpty) {
      outputExtensions = extensions;
    } else {
      throw BuildConfigError('Expected a non-empty `outputExtensions` key in ${asset.shortUri}');
    }
  }
  late final optionsTypeChecker = resolver.typeCheckerFor('BuilderOptions', _leanBuilders);
  bool expectsOptions = false;
  final constructor = element.unnamedConstructor;
  if (constructor != null) {
    if (constructor.parameters.length > 1) {
      throw BuildConfigError(
        'Expected a constructor with no parameters or one positional parameter of type (BuilderOptions)',
      );
    }
    final options = constructor.parameters.isNotEmpty ? constructor.parameters.first : null;
    if (options != null && (!options.isPositional || !optionsTypeChecker.isExactlyType(options.type))) {
      throw BuildConfigError('Expected a parameter of exact type BuilderOptions, but got ${options.type}');
    }
    expectsOptions = options != null;
  }

  final typesToRegister = <RuntimeTypeRegisterEntry>[];
  final import = _resolveImport(asset.shortUri)!;
  final annotationRefs = constObj.getSet('annotations')?.value;
  final types = {...?annotationRefs?.whereType<ConstType>().map((e) => e.value)};
  final superType = element.superType;
  if (superType is InterfaceType && superType.typeArguments.isNotEmpty) {
    types.addAll(superType.typeArguments);
  }

  for (final type in types) {
    if (type is! InterfaceType) {
      throw BuildConfigError('Expected an InterfaceType for annotation reference');
    }
    final typeImport = resolver.uriForAsset(type.declarationRef.srcId);
    typesToRegister.add(RuntimeTypeRegisterEntry(type.name, _resolveImport(typeImport), type.declarationRef.srcId));
  }

  final builderDef = BuilderDefinitionEntry(
    import: import,
    builderType: builderType,
    generatorName: element.name,
    expectsOptions: expectsOptions,
    outputExtensions: outputExtensions,
    annotationsTypeMap: typesToRegister.isEmpty ? null : typesToRegister,
    key: constObj.getString('key')?.value ?? element.name,
    generateToCache: constObj.getBool('generateToCache')?.value,
    options: constObj.getMap('options')?.literalValue.cast<String, dynamic>(),
    generateFor: constObj.getSet('generateFor')?.literalValue.cast<String>(),
    runsBefore: constObj.getSet('runsBefore')?.literalValue.cast<String>(),
    allowSyntaxErrors: constObj.getBool('allowSyntaxErrors')?.value,
    applies: constObj.getSet('applies')?.literalValue.cast<String>(),
  );
  return builderDef;
}

String? _resolveImport(Uri uri) {
  if (uri.scheme == 'dart' && uri.pathSegments.firstOrNull == 'core') {
    return null;
  }
  if (uri.scheme == 'asset') {
    final targetUri = Uri.parse(p.join(p.current, scriptOutput));
    return p.relative(uri.path, from: targetUri.path);
  } else {
    return uri.toString();
  }
}
