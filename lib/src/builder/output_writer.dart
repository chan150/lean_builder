import 'dart:io';
import 'package:lean_builder/src/asset/asset.dart' show Asset;
import 'package:lean_builder/src/builder/builder_impl.dart';
import 'package:path/path.dart' as p;

abstract class OutputWriter {
  /// Writes the [content] to the output file at [path].
  ///
  /// The [extension] is the file extension of the output file.
  Future<void> writeString(Uri fileUri, String content, bool isPart);

  /// Writes the [content] to the output file at [path].
  ///
  /// The [extension] is the file extension of the output file.
  Future<void> writeBytes(Uri fileUri, List<int> content, bool isPart);
}

class DeferredOutputWriter implements OutputWriter {
  final Asset input;
  final List<WriteOperation> _operations = [];

  DeferredOutputWriter(this.input);

  bool get hasPendingOperations => _operations.isNotEmpty;

  @override
  Future<void> writeString(Uri fileUri, String content, bool isPart) async {
    final operation = WriteStringOperation(fileUri, content, isPart: isPart);
    _operations.add(operation);
  }

  @override
  Future<void> writeBytes(Uri fileUri, List<int> content, bool isPart) async {
    final operation = WriteBytesOperation(fileUri, content, isPart: isPart);
    _operations.add(operation);
  }

  /// Flushes all non-part outputs and returns the generated files.
  Future<Set<Uri>> flushOutputs() async {
    final generatedFiles = <Uri>{};
    final nonParts = _operations.where((op) => !op.isPart);
    for (final operation in nonParts) {
      await operation.execute();
      generatedFiles.add(operation.fileUri);
      _operations.remove(operation);
    }
    return generatedFiles;
  }

  /// Flushes all part outputs and returns the generated file.
  Future<Uri?> flushSharedOutput() async {
    final parts = _operations.where((op) => op.isPart);
    if (parts.isEmpty) return null;

    // all parts must have the same output uri
    final outputUri = parts.first.fileUri;
    for (final part in parts) {
      if (part.fileUri != outputUri) {
        throw ArgumentError('All parts must have the same output uri');
      }
    }

    final inputUri = input.uri;
    final file = File.fromUri(outputUri);
    if (file.existsSync()) {
      file.deleteSync();
    }
    final partOf = p.relative(inputUri.path, from: p.dirname(outputUri.path));
    final header = [defaultFileHeader, "part of '$partOf';"].join('\n\n');
    for (var i = 0; i < parts.length; i++) {
      final operation = parts.elementAt(i);
      if (i == 0) {
        await operation.execute(header: header);
      } else {
        await operation.execute(header: '\n');
      }
      _operations.remove(operation);
    }
    return outputUri;
  }
}

sealed class WriteOperation {
  final bool isPart;
  final Uri fileUri;

  WriteOperation(this.fileUri, {this.isPart = false});

  Future<void> execute({String? header});
}

class WriteStringOperation extends WriteOperation {
  final String contents;

  WriteStringOperation(super.fileUri, this.contents, {super.isPart});

  @override
  Future<void> execute({String? header}) {
    final mode = isPart ? FileMode.append : FileMode.write;
    String output = contents;
    if (header != null) {
      output = '$header\n\n$contents';
    }
    return File.fromUri(fileUri).writeAsString(output, mode: mode);
  }
}

class WriteBytesOperation extends WriteOperation {
  final List<int> contents;

  WriteBytesOperation(super.fileUri, this.contents, {super.isPart});

  @override
  Future<void> execute({String? header}) {
    if (header != null) {
      throw ArgumentError('Header is not supported for bytes');
    }
    final mode = isPart ? FileMode.append : FileMode.write;
    return File.fromUri(fileUri).writeAsBytes(contents, mode: mode);
  }
}
