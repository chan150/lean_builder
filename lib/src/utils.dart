// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';



bool hasExpectedPartDirective(CompilationUnit unit, String part) =>
    unit.directives.whereType<PartDirective>().any((e) => e.uri.stringValue == part);

/// Returns a URL representing [element].
String urlOfElement(Element element) =>
    element.kind == ElementKind.DYNAMIC
        ? 'dart:core#dynamic'
        // using librarySource.uri – in case the element is in a part
        : normalizeUrl(element.librarySource!.uri).replace(fragment: element.name).toString();

Uri normalizeUrl(Uri url) => switch (url.scheme) {
  'dart' => normalizeDartUrl(url),
  'package' => packageToAssetUrl(url),
  'file' => fileToAssetUrl(url),
  _ => url,
};

/// Make `dart:`-type URLs look like a user-knowable path.
///
/// Some internal dart: URLs are something like `dart:core/map.dart`.
///
/// This isn't a user-knowable path, so we strip out extra path segments
/// and only expose `dart:core`.
Uri normalizeDartUrl(Uri url) =>
    url.pathSegments.isNotEmpty ? url.replace(pathSegments: url.pathSegments.take(1)) : url;

Uri fileToAssetUrl(Uri url) {
  if (!p.isWithin(p.url.current, url.path)) return url;
  return Uri(scheme: 'asset', path: p.join(rootPackageName, p.relative(url.path)));
}

/// Returns a `package:` URL converted to a `asset:` URL.
///
/// This makes internal comparison logic much easier, but still allows users
/// to define assets in terms of `package:`, which is something that makes more
/// sense to most.
///
/// For example, this transforms `package:source_gen/source_gen.dart` into:
/// `asset:source_gen/lib/source_gen.dart`.
Uri packageToAssetUrl(Uri url) =>
    url.scheme == 'package'
        ? url.replace(
          scheme: 'asset',
          pathSegments: <String>[url.pathSegments.first, 'lib', ...url.pathSegments.skip(1)],
        )
        : url;

/// Returns a `asset:` URL converted to a `package:` URL.
///
/// For example, this transformers `asset:source_gen/lib/source_gen.dart' into:
/// `package:source_gen/source_gen.dart`. Asset URLs that aren't pointing to a
/// file in the 'lib' folder are not modified.
///
/// Asset URLs come from `package:build`, as they are able to describe URLs that
/// are not describable using `package:...`, such as files in the `bin`, `tool`,
/// `web`, or even root directory of a package - `asset:some_lib/web/main.dart`.
Uri assetToPackageUrl(Uri url) =>
    url.scheme == 'asset' && url.pathSegments.isNotEmpty && url.pathSegments[1] == 'lib'
        ? url.replace(scheme: 'package', pathSegments: [url.pathSegments.first, ...url.pathSegments.skip(2)])
        : url;

final String rootPackageName = () {
  final name = (loadYaml(File('pubspec.yaml').readAsStringSync()) as Map)['name'];
  if (name is! String) {
    throw StateError(
      'Your pubspec.yaml file is missing a `name` field or it isn\'t '
      'a String.',
    );
  }
  return name;
}();

/// Returns a valid buildExtensions map created from [optionsMap] or
/// returns [defaultExtensions] if no 'build_extensions' key exists.
///
/// Modifies [optionsMap] by removing the `build_extensions` key from it, if
/// present.
Map<String, List<String>> validatedBuildExtensionsFrom(
  Map<String, dynamic>? optionsMap,
  Map<String, List<String>> defaultExtensions,
) {
  final extensionsOption = optionsMap?.remove('build_extensions');
  if (extensionsOption == null) {
    // defaultExtensions are provided by the builder author, not the end user.
    // It should be safe to skip validation.
    return defaultExtensions;
  }

  if (extensionsOption is! Map) {
    throw ArgumentError('Configured build_extensions should be a map from inputs to outputs.');
  }

  final result = <String, List<String>>{};

  for (final entry in extensionsOption.entries) {
    final input = entry.key;
    if (input is! String || !input.endsWith('.dart')) {
      throw ArgumentError(
        'Invalid key in build_extensions option: `$input` '
        'should be a string ending with `.dart`',
      );
    }

    final output = (entry.value is List) ? entry.value as List : [entry.value];

    for (var i = 0; i < output.length; i++) {
      final o = output[i];
      if (o is! String || (i == 0 && !o.endsWith('.dart'))) {
        throw ArgumentError(
          'Invalid output extension `${entry.value}`. It should be a string '
          'or a list of strings with the first ending with `.dart`',
        );
      }
    }

    result[input] = output.cast<String>().toList();
  }

  if (result.isEmpty) {
    throw ArgumentError('Configured build_extensions must not be empty.');
  }

  return result;
}

extension FileX on File {
  String? readAsStringSyncSafe() {
    try {
      if (!existsSync()) {
        return null;
      }
      return readAsStringSync();
    } catch (e) {
      return null;
    }
  }
}
