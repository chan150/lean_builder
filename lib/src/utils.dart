import 'dart:io' show File;

import 'package:yaml/yaml.dart' show YamlMap, loadYaml;

/// The name of the root package as defined in its pubspec.yaml file.
///
/// This is loaded once when the app starts and cached for future use.
/// Throws a [StateError] if the pubspec.yaml file doesn't contain a valid
/// 'name' field.
final String rootPackageName = () {
  final dynamic name = (loadYaml(File('pubspec.yaml').readAsStringSync()) as YamlMap)['name'];
  if (name is! String) {
    throw StateError(
      'Your pubspec.yaml file is missing a `name` field or it isn\'t '
      'a String.',
    );
  }
  return name;
}();
