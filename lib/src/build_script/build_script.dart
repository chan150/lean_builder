import 'dart:io';

import 'package:collection/collection.dart';
import 'package:dart_style/dart_style.dart';
import 'package:lean_builder/src/asset/package_file_resolver.dart';
import 'package:lean_builder/src/build_script/errors.dart';
import 'package:lean_builder/src/build_script/generator.dart';
import 'package:lean_builder/src/build_script/parsed_builder_entry.dart';
import 'package:lean_builder/src/logger.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import 'compile.dart' as compile;
import 'files.dart';

String? prepareBuildScript() {
  final resolver = PackageFileResolver.forRoot();
  final configFiles = _detectConfigFiles(resolver);
  final entries = _parseAll(configFiles);
  final digestFile = File(scriptDigest);
  final scriptFile = File(scriptOutput);

  if (entries.isEmpty) {
    if (scriptFile.existsSync()) {
      scriptFile.deleteSync();
    }
    if (digestFile.existsSync()) {
      digestFile.deleteSync();
    }
    return null;
  }

  final withOverrides = _handleOverrides(entries, resolver);
  final scriptHash = const ListEquality().hash(withOverrides).toString();

  if (scriptFile.existsSync() && digestFile.existsSync()) {
    final currentHash = digestFile.readAsStringSync();
    if (currentHash == scriptHash) {
      /// The script is up to date, no need to recompile.
      return scriptFile.path;
    }
  }

  Logger.info('Generating a new build script...');
  var script = generateBuildScript(withOverrides, scriptHash);
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
            options: (builder['options'] as YamlMap?)?.map((k, v) => MapEntry("'$k'", v)),
            generateToCache: builder['generate_to_cache'] == true,
            generateFor: generateFor?.map((e) => "'$e'").toSet(),
            runsBefore: getRunsBeforeSet(builder['runs_before']),
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
          final generateFor = builder['generate_for'] as YamlList?;

          final key = entry.key.toString();
          if (key.split(':').length != 2) {
            throw BuildConfigError("Expected a valid builder key '<package>:<builder>' in ${file.path}");
          }
          final builderEntry = BuilderOverrideEntry(
            key: key,
            package: config.key,
            options: builder['options'] as Map<String, dynamic>?,
            generateFor: generateFor?.map((e) => "'$e'").toSet(),
            runsBefore: getRunsBeforeSet(builder['runs_before']),
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
