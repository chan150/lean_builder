// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:lean_builder/builder.dart';
import 'package:lean_builder/src/asset/asset.dart' show Asset;
import 'package:lean_builder/src/element/element.dart';
import 'package:lean_builder/src/resolvers/resolver.dart';
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

  /// The [Resolver] for this build step.
  Resolver get resolver;

  /// The writing methods [writeAsBytes] and [writeAsString] will throw an
  /// `InvalidOutputException` when attempting to write an asset not part of
  /// the [allowedExtensions].
  ///
  Set<String> get allowedExtensions;

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
  FutureOr<void> writeAsBytes(List<int> bytes, String extension);

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
  FutureOr<void> writeAsString(String contents, String extension, {Encoding encoding = utf8});

  /// Returns true if the input library has a part directive for the given
  /// extension.
  bool hasValidPartDirectiveFor(String extension);

  Set<Uri> get outputs;
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
  Set<Uri> get outputs => _outputs;

  final Set<Uri> _outputs = <Uri>{};

  @override
  FutureOr<void> writeAsBytes(List<int> bytes, String extension) async {
    final outputUri = asset.uriWithExtension(extension);
    _validateOutput(outputUri);
    await File.fromUri(outputUri).writeAsBytes(bytes);
    _outputs.add(outputUri);
  }

  @override
  void writeAsString(String extension, String contents, {Encoding encoding = utf8}) {
    final outputUri = asset.uriWithExtension(extension);
    _validateOutput(outputUri);
    final file = File.fromUri(outputUri);
    file.writeAsStringSync(contents, encoding: encoding);
    _outputs.add(outputUri);
  }

  void _validateOutput(Uri uri) {
    final extDotIndex = uri.path.indexOf('.');
    if (extDotIndex == -1 || !allowedExtensions.contains(uri.path.substring(extDotIndex))) {
      throw Exception('Invalid extension, allowed extensions are: $allowedExtensions');
    }
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
      if (partUri == asset.uriWithExtension(extension)) {
        return true;
      }
    }
    return false;
  }
}

class SharedBuildStep extends BuildStepImpl {
  final _buffer = StringBuffer();

  final Uri outputUri;

  SharedBuildStep(super.asset, super.resolver, {required this.outputUri})
    : super(allowedExtensions: {SharedPartBuilder.extension});

  @override
  Future<void> writeAsBytes(List<int> bytes, String extension) async {
    assert(outputUri == asset.uriWithExtension(extension), 'Unexpected output uri, expected $outputUri');
    _buffer.writeln(utf8.decode(bytes));
  }

  @override
  Future<void> writeAsString(String extension, String contents, {Encoding encoding = utf8}) async {
    assert(encoding == utf8, 'Only utf8 encoding is supported for deferred outputs');
    assert(outputUri == asset.uriWithExtension(extension), 'Unexpected output uri, expected $outputUri');
    _buffer.writeln(contents);
  }

  Future<void> flush() async {
    final partOf = p.relative(asset.uri.path, from: p.dirname(outputUri.path));
    final header = [defaultFileHeader, "part of '$partOf';"].join('\n\n');
    final content = _buffer.toString();

    final file = File.fromUri(outputUri);
    file.writeAsStringSync('$header\n\n$content');
    _buffer.clear();
    outputs.add(outputUri);
  }
}
