import 'dart:io';

import 'package:collection/collection.dart';
import 'package:dart_style/dart_style.dart';
import 'package:lean_builder/src/asset/package_file_resolver.dart';
import 'package:lean_builder/src/build_script/errors.dart';
import 'package:lean_builder/src/build_script/generator.dart';
import 'package:lean_builder/src/build_script/parsed_builder_entry.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import 'compile.dart' as compile;

const _scriptOutput = '.dart_tool/lean_build/lean_build.dart';
const _scriptDigest = '.dart_tool/lean_build/lean_build.digest';

String? prepareBuildScript() {
  final resolver = PackageFileResolver.forRoot();
  final configFiles = _detectConfigFiles(resolver);
  final entries = _parseAll(configFiles);
  final digestFile = File(_scriptDigest);
  final scriptFile = File(_scriptOutput);

  if (entries.isEmpty) {
    if (scriptFile.existsSync()) {
      scriptFile.deleteSync();
    }
    if (digestFile.existsSync()) {
      digestFile.deleteSync();
    }
    return null;
  }

  final finalEntries = _handleOverrides(entries, resolver);
  final scriptHash = const ListEquality().hash(finalEntries);

  if (scriptFile.existsSync() && digestFile.existsSync()) {
    final currentHash = digestFile.readAsStringSync();
    if (currentHash == scriptHash.toString()) {
      /// The script is up to date, no need to recompile.
      return scriptFile.path;
    }
  }
  var script = generateBuildScript(finalEntries);
  final formatter = DartFormatter(languageVersion: DartFormatter.latestShortStyleLanguageVersion);
  script = formatter.format(script);

  if (!scriptFile.existsSync()) {
    scriptFile.createSync(recursive: true);
  }
  scriptFile.writeAsStringSync(script);

  if (!digestFile.existsSync()) {
    digestFile.createSync(recursive: true);
  }
  digestFile.writeAsStringSync(scriptHash.toString());
  compile.invalidateExecutable();
  return scriptFile.path;
}

List<BuilderDefinitionEntry> _handleOverrides(List<ParsedBuilderEntry> entries, PackageFileResolver resolver) {
  final definitions = entries.whereType<BuilderDefinitionEntry>();
  final checkedKeys = <String>{};
  final finalEntries = <BuilderDefinitionEntry>[];
  final rootOverrides = entries.whereType<BuilderOverrideEntry>().where((e) => e.package == resolver.rootPackage);
  for (final def in definitions) {
    if (checkedKeys.contains(def.key)) {
      throw BuildConfigError('Duplicate builder key found: ${def.key}');
    }
    checkedKeys.add(def.key);
    final rootOverride = rootOverrides.firstWhereOrNull((e) => e.key == def.key);
    if (rootOverride == null) {
      finalEntries.add(def);
    } else {
      finalEntries.add(def.merge(rootOverride));
    }
  }
  return finalEntries;
}

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

List<ParsedBuilderEntry> _parseAll(Map<String, File> configFiles) {
  final parsedEntries = <ParsedBuilderEntry>[];
  try {
    for (final config in configFiles.entries) {
      final file = config.value;
      final yaml = loadYaml(file.readAsStringSync()) as Map;
      final builders = yaml['builders'] as Map?;
      final buildersOverride = yaml['builders_override'] as Map?;
      if (builders == null && buildersOverride == null) {
        throw BuildConfigError('Expected a `builders` or `builders_override` key in ${file.path}');
      }

      if (builders != null) {
        if (builders.isEmpty) {
          throw BuildConfigError('Expected a non-empty `builders` key in ${file.path}');
        }
        for (final entry in builders.entries) {
          final builder = entry.value;
          final import = builder['import'] as String?;
          if (import == null || Uri.tryParse(import)?.scheme != 'package') {
            throw BuildConfigError('Expected a valid `import` key in ${file.path}');
          }
          final builderFactory = builder['builder_factory'] as String?;
          if (builderFactory == null) {
            throw BuildConfigError('Expected a valid `builder_factory` key in ${file.path}');
          }
          final generateFor = builder['generate_for'] as YamlList?;
          final builderEntry = BuilderDefinitionEntry(
            key: '${config.key}:${entry.key}',
            package: config.key,
            import: import,
            builderFactory: builderFactory,
            options: builder['options'] as Map<String, dynamic>?,
            hideOutput: builder['hide_output'] == true,
            generateFor: generateFor?.map((e) => "'$e'").toSet(),
          );
          parsedEntries.add(builderEntry);
        }
      }

      if (buildersOverride != null) {
        if (buildersOverride.isEmpty) {
          throw BuildConfigError('Expected a non-empty `builders_override` key in ${file.path}');
        }
        for (final entry in buildersOverride.entries) {
          final builder = entry.value;
          final generateFor = builder['generate_for'] as List<String>?;
          final key = entry.key.toString();
          if (key.split(':').length != 2) {
            throw BuildConfigError("Expected a valid builder key '<package>:<builder>' in ${file.path}");
          }
          final builderEntry = BuilderOverrideEntry(
            key: key,
            package: config.key,
            options: builder['options'] as Map<String, dynamic>?,
            generateFor: generateFor?.toSet(),
          );
          parsedEntries.add(builderEntry);
        }
      }
    }
    return parsedEntries;
  } catch (e) {
    throw BuildConfigError(e.toString());
  }
}
