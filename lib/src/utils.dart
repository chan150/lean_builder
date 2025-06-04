import 'dart:io' show File;

import 'package:yaml/yaml.dart' show YamlMap, loadYaml;

/// The name of the root package as defined in its pubspec.yaml file.
///
/// This is loaded once when the app starts and cached for future use.
/// Throws a [StateError] if the pubspec.yaml file doesn't contain a valid
/// 'name' field.
final String rootPackageName = () {
  final dynamic name = rootPackagePubspec['name'];
  if (name is! String) {
    throw StateError(
      'Your pubspec.yaml file is missing a `name` field or it isn\'t '
      'a String.',
    );
  }
  return name;
}();

/// The root package's pubspec.yaml file as a [YamlMap].
///
/// This is loaded once when the app starts and cached for future use.
/// Throws a [StateError] if the pubspec.yaml file is not valid or does not exist.
final YamlMap rootPackagePubspec = () {
  try {
    final dynamic pubspec = loadYaml(File('pubspec.yaml').readAsStringSync());
    if (pubspec is! YamlMap) {
      throw StateError(
        'Your pubspec.yaml file is not a valid YAML map.',
      );
    }
    return pubspec;
  } catch (e) {
    throw StateError(
      'Failed to load pubspec.yaml: $e. Make sure it exists and is valid.',
    );
  }
}();

/// All packages that are hosted on a path in the root package's pubspec.yaml.
///
/// This includes packages listed under `dependencies`, `dev_dependencies`, and
/// `dependency_overrides` that have a `path` specified.
final Set<String> pathHostedPackages = () {
  final Set<String> packages = <String>{};
  _getPathHostedPackages(rootPackagePubspec['dependencies'], packages);
  _getPathHostedPackages(rootPackagePubspec['dev_dependencies'], packages);
  _getPathHostedPackages(rootPackagePubspec['dependency_overrides'], packages);
  return packages;
}();

void _getPathHostedPackages(dynamic dependencies, Set<String> packages) {
  if (dependencies is YamlMap) {
    for (final key in dependencies.keys) {
      if (dependencies[key] is YamlMap && dependencies[key]['path'] != null) {
        packages.add(key.toString());
      }
    }
  }
}
