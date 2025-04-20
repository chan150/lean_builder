// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:lean_builder/src/resolvers/element/element.dart';
import 'package:lean_builder/src/resolvers/resolver.dart';
import 'package:lean_builder/src/resolvers/file_asset.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

/// some of the abstractions are borrowed from the build package

/// A single step in a build process.
///
/// This represents a single [asset], logic around resolving as a library,
/// and the ability to read and write assets as allowed by the underlying build
/// system.

abstract class BuildStep {
  /// The primary input for this build step.
  Asset get asset;

  LibraryElement get inputLibrary;

  /// Writes [bytes] to a binary file located at [id].
  ///
  /// Returns a [Future] that completes after writing the asset out.
  ///
  /// * Throws an `InvalidOutputException` if the output was not valid (that is,
  ///   [id] is not in [allowedExtensions])
  ///
  /// **NOTE**: Most `Builder` implementations should not need to `await` this
  /// Future since the runner will be responsible for waiting until all outputs
  /// are written.
  /// [extension] is the extension of the file to be written. It should be one of
  /// the extensions declared in the builder's `buildExtensions`.
  Future<void> writeAsBytes(Asset asset, String extension, List<int> bytes);

  /// Writes [contents] to a text file located at [id] with [encoding].
  ///
  /// Returns a [Future] that completes after writing the asset out.
  ///
  /// * Throws an `InvalidOutputException` if the output was not valid (that is,
  ///   [id] is not in [allowedExtensions])
  ///
  /// **NOTE**: Most `Builder` implementations should not need to `await` this
  /// Future since the runner will be responsible for waiting until all outputs
  /// are written.
  ///
  /// [extension] is the extension of the file to be written. It should be one of
  /// the extensions declared in the builder's `buildExtensions`.
  Future<void> writeAsString(Asset asset, String extension, String contents, {Encoding encoding = utf8});

  /// The [Resolver] for this build step.
  Resolver get resolver;

  /// Returns assets that may be written in this build step.
  ///
  /// Allowed outputs are formed by matching the [inputId] against the builder's
  /// `buildExtensions`, which declares a list of output extensions for this
  /// input.
  ///
  /// The writing methods [writeAsBytes] and [writeAsString] will throw an
  /// `InvalidOutputException` when attempting to write an asset not part of
  /// the [allowedExtensions].
  ///

  Set<String> get allowedExtensions;

  /// Returns true if the input library has a part directive for the given
  /// extension.
  bool hasValidPartDirectiveFor(String extension);
}

class BuildStepImpl implements BuildStep {
  @override
  final Asset asset;

  @override
  final Resolver resolver;

  BuildStepImpl(this.asset, this.resolver, {required this.allowedExtensions});

  @override
  final Set<String> allowedExtensions;

  @override
  LibraryElement get inputLibrary => resolver.libraryFor(asset);

  @override
  Future<void> writeAsBytes(Asset asset, String extension, List<int> bytes) async {
    final outputUri = _changeExtension(asset, extension);
    _validateOutput(outputUri);
    final outputFile = File.fromUri(outputUri);
    await outputFile.writeAsBytes(bytes);
  }

  @override
  Future<void> writeAsString(Asset asset, String extension, String contents, {Encoding encoding = utf8}) async {
    final outputUri = _changeExtension(asset, extension);
    _validateOutput(outputUri);
    final outputFile = File.fromUri(outputUri);
    await outputFile.writeAsString(contents, encoding: encoding);
  }

  void _validateOutput(Uri uri) {
    final extDotIndex = uri.path.indexOf('.');
    if (extDotIndex == -1 || !allowedExtensions.contains(uri.path.substring(extDotIndex))) {
      throw Exception('Invalid output: $uri. No extension found.');
    }
  }

  /// Changes the extension of the asset's URI to the new extension.
  Uri _changeExtension(Asset asset, String newExtension) {
    final uri = asset.uri;
    return uri.replace(path: p.withoutExtension(uri.path) + newExtension);
  }

  @override
  bool hasValidPartDirectiveFor(String extension) {
    final library = inputLibrary;
    final partDirectives = library.compilationUnit.directives.whereType<PartDirective>();
    final fileResolver = resolver.fileResolver;
    for (final partDirect in partDirectives) {
      final part = partDirect.uri.stringValue;
      if (part == null) continue;
      final partUri = fileResolver.resolveFileUri(Uri.parse(part), relativeTo: library.src.uri);
      if (partUri == _changeExtension(asset, extension)) {
        return true;
      }
    }
    return false;
  }
}
