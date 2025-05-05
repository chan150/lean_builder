import 'dart:io';

import 'package:dart_style/dart_style.dart';
import 'package:lean_builder/builder.dart';
import 'package:lean_builder/element.dart';
import 'package:lean_builder/src/asset/package_file_resolver.dart';
import 'package:lean_builder/src/build_script/errors.dart';
import 'package:lean_builder/src/build_script/generator.dart';
import 'package:lean_builder/src/build_script/parsed_builder_entry.dart';
import 'package:lean_builder/src/graph/asset_scan_manager.dart';
import 'package:lean_builder/src/graph/scan_results.dart';
import 'package:lean_builder/src/logger.dart';
import 'package:lean_builder/src/type/type.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import 'compile.dart' as compile;
import 'files.dart';

const String _leanAnnotations = 'package:lean_builder/src/build_script/annotations.dart';
const String _leanGenerator = 'package:lean_builder/src/builder/generator/generator.dart';
const String _leanBuilders = 'package:lean_builder/src/builder/builder.dart';

String? prepareBuildScript(Set<ProcessableAsset> assets, Resolver resolver) {
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

  final entries = _parseAll(assets, resolver);
  if (entries.isEmpty) {
    deleteScriptFile();
    return null;
  }

  // final withOverrides = _handleOverrides(entries, fileResolver);

  Logger.info('Generating a new build script...');
  var script = generateBuildScript(entries.whereType<BuilderDefinitionEntry>().toList());
  final formatter = DartFormatter(languageVersion: DartFormatter.latestShortStyleLanguageVersion);
  script = formatter.format(script);

  if (!scriptFile.existsSync()) {
    scriptFile.createSync(recursive: true);
  }
  scriptFile.writeAsStringSync(script);

  compile.invalidateExecutable();
  return scriptFile.path;
}

// List<BuilderDefinitionEntry> _handleOverrides(List<ParsedBuilderEntry> entries, PackageFileResolver resolver) {
//   final definitions = entries.whereType<BuilderDefinitionEntry>();
//   final checkedKeys = <String>{};
//   final finalEntries = <BuilderDefinitionEntry>[];
//   final rootOverrides = entries.whereType<BuilderOverrideEntry>().where((e) => e.package == resolver.rootPackage);
//   for (final def in definitions) {
//     if (checkedKeys.contains(def.key)) {
//       throw BuildConfigError('Duplicate builder key found: ${def.key}');
//     }
//     checkedKeys.add(def.key);
//     final rootOverride = rootOverrides.firstWhereOrNull((e) => e.key == def.key);
//     if (rootOverride == null) {
//       finalEntries.add(def);
//     } else {
//       finalEntries.add(def.merge(rootOverride));
//     }
//   }
//   return finalEntries;
// }

Map<String, File> _detectConfigFiles(PackageFileResolver resolver) {
  final packages = resolver.packages;
  final configFiles = <String, File>{};
  for (final package in packages) {
    final path = resolver.pathFor(package);
    final buildYaml = File.fromUri(Uri.parse(p.join(path, 'lean.yaml')));
    if (buildYaml.existsSync()) {
      configFiles[package] = buildYaml;
    }
  }
  return configFiles;
}

List<ParsedBuilderEntry> _parseAll(Set<ProcessableAsset> assets, Resolver resolver) {
  final parsedEntries = <ParsedBuilderEntry>[];
  late final leanGenTypeChecker = resolver.typeCheckerFor('LeanGenerator', _leanAnnotations);
  late final leanBuilderTypeChecker = resolver.typeCheckerFor('LeanBuilder', _leanAnnotations);
  late final generatorTypeChecker = resolver.typeCheckerFor('Generator', _leanGenerator);
  late final builderTypeChecker = resolver.typeCheckerFor('Builder', _leanBuilders);
  late final optionsTypeChecker = resolver.typeCheckerFor('BuilderOptions', _leanBuilders);

  for (final entry in assets) {
    final library = resolver.resolveLibrary(entry.asset);
    for (final annotatedElement in library.annotatedWithExact(leanGenTypeChecker)) {
      final element = annotatedElement.element;
      if (element is! ClassElement) {
        throw BuildConfigError('Expected a class element for generator annotation');
      }
      final superType = element.superType;
      if (superType == null || !generatorTypeChecker.isSupertypeOf(superType)) {
        throw BuildConfigError('Expected a class that extends Generator for generator annotation');
      }

      final constructor = element.unnamedConstructor;
      if (constructor == null || constructor.parameters.length > 1) {
        throw BuildConfigError(
          'Expected a constructor with no parameters or one positional parameter of type (BuilderOptions)',
        );
      }

      final options = constructor.parameters.isNotEmpty ? constructor.parameters.first : null;
      if (options != null && (!options.isPositional || !optionsTypeChecker.isExactlyType(options.type))) {
        throw BuildConfigError('Expected a parameter of exact type BuilderOptions, but got ${options.type}');
      }

      final constObj = annotatedElement.annotation.constant;
      if (constObj is! ConstObject) {
        throw BuildConfigError('Could not read annotation object');
      }

      final isShared = constObj.constructorName == 'shared';
      final import = _resolveImport(entry.asset.shortUri)!;
      final typesToRegister = <AnnotationReg>[];
      final annotationRefs = constObj.getSet('annotations')?.value;
      final types = {...?annotationRefs?.whereType<ConstType>().map((e) => e.value)};

      if (superType is InterfaceType && superType.typeArguments.isNotEmpty) {
        types.addAll(superType.typeArguments);
      }

      for (final type in types) {
        if (type is! InterfaceType) {
          throw BuildConfigError('Expected an InterfaceType for annotation reference');
        }
        final typeImport = resolver.uriForAsset(type.declarationRef.srcId);
        typesToRegister.add(AnnotationReg(type.name, _resolveImport(typeImport), type.declarationRef.srcId));
      }

      final builderDef = BuilderDefinitionEntry(
        expectsOptions: constructor.parameters.isNotEmpty,
        key: constObj.getString('key')?.value ?? element.name,
        import: import,
        generatorName: element.name,
        generateToCache: constObj.getBool('generateToCache')?.value,
        options: constObj.getMap('options')?.literalValue.cast<String, dynamic>(),
        generateFor: constObj.getSet('generateFor')?.literalValue.cast<String>(),
        runsBefore: constObj.getSet('runsBefore')?.literalValue.cast<String>(),
        allowSyntaxErrors: constObj.getBool('allowSyntaxErrors')?.value,
        builderType: isShared ? BuilderType.shared : BuilderType.library,
        annotationsTypeMap: typesToRegister,
      );
      parsedEntries.add(builderDef);
    }
  }

  return parsedEntries;

  // for (final config in configFiles.entries) {
  //   final file = config.value;
  //   final yaml = loadYaml(file.readAsStringSync()) as Map;
  //   final builders = yaml['builders'] as Map?;
  //   final buildersOverride = yaml['builders_override'] as Map?;
  //
  //   if (builders != null) {
  //     if (builders.isEmpty) {
  //       throw BuildConfigError('Expected a non-empty `builders` key in ${file.path}');
  //     }
  //     for (final entry in builders.entries) {
  //       final builder = entry.value;
  //       final import = builder['import'] as String?;
  //       if (import == null) {
  //         throw BuildConfigError('Expected a valid `import` key in ${file.path}');
  //       }
  //       final builderFactory = builder['builder_factory'] as String?;
  //       if (builderFactory == null) {
  //         throw BuildConfigError('Expected a valid `builder_factory` key in ${file.path}');
  //       }
  //       final generateFor = builder['generate_for'] as YamlList?;
  //       final builderEntry = BuilderDefinitionEntry(
  //         key: '${config.key}:${entry.key}',
  //         package: config.key,
  //         import: import,
  //         builderFactory: builderFactory,
  //         options: (builder['options'] as YamlMap?)?.map((k, v) => MapEntry("'$k'", v)),
  //         generateToCache: builder['generate_to_cache'] == true,
  //         generateFor: generateFor?.map((e) => "'$e'").toSet(),
  //         runsBefore: getRunsBeforeSet(builder['runs_before']),
  //       );
  //       parsedEntries.add(builderEntry);
  //     }
  //   }
  //
  //   if (buildersOverride != null) {
  //     if (buildersOverride.isEmpty) {
  //       throw BuildConfigError('Expected a non-empty `builders_override` key in ${file.path}');
  //     }
  //     for (final entry in buildersOverride.entries) {
  //       final builder = entry.value;
  //       final generateFor = builder['generate_for'] as YamlList?;
  //
  //       final key = entry.key.toString();
  //       if (key.split(':').length != 2) {
  //         throw BuildConfigError("Expected a valid builder key '<package>:<builder>' in ${file.path}");
  //       }
  //       final builderEntry = BuilderOverrideEntry(
  //         key: key,
  //         package: config.key,
  //         options: builder['options'] as Map<String, dynamic>?,
  //         generateFor: generateFor?.map((e) => "'$e'").toSet(),
  //         runsBefore: getRunsBeforeSet(builder['runs_before']),
  //       );
  //       parsedEntries.add(builderEntry);
  //     }
  //   }
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

Set<String>? getRunsBeforeSet(YamlList? list) {
  if (list == null) {
    return null;
  }
  final runsBefore = <String>{};
  for (final entry in list) {
    if (entry is String) {
      final parts = entry.split(':');
      if (parts.length != 2) {
        throw BuildConfigError('Expected a valid builder name `<package>:<builder-name>` in `runs_before`');
      }
      runsBefore.add("'$entry'");
    } else {
      throw BuildConfigError('Expected a string in `runs_before` key');
    }
  }
  return runsBefore;
}
