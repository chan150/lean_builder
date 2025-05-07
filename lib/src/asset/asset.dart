import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:lean_builder/src/logger.dart';
import 'package:path/path.dart' as p;

abstract class Asset {
  String get id;

  Uri get shortUri;

  Uri get uri;

  Uint8List readAsBytesSync();

  String readAsStringSync({Encoding encoding = utf8});

  bool existsSync();

  factory Asset({required String id, required Uri shortUri, required File file}) = FileAsset;

  Map<String, dynamic> toJson();

  /// if [shortUri] is a package uri, e.g `package:foo/bar.dart`, return `foo`
  /// if [shortUri] is an asset uri, e.g  `asset:foo/bar.dart`, return `foo`
  /// if [shortUri] is a dart uri, e.g `dart:core/string.dart`, return `dart`
  /// otherwise return null
  String? get packageName;

  Uri uriWithExtension(String ext);

  void safeDelete();
}

class FileAsset implements Asset {
  final File file;

  @override
  final String id;

  @override
  final Uri shortUri;

  FileAsset({required this.file, required this.shortUri, required this.id});

  @override
  Uri get uri => file.uri;

  @override
  Uint8List readAsBytesSync() {
    return file.readAsBytesSync();
  }

  @override
  String readAsStringSync({Encoding encoding = utf8}) {
    return file.readAsStringSync(encoding: encoding);
  }

  @override
  bool existsSync() => file.existsSync();

  @override
  String toString() {
    return 'FileAsset{file: $file, pathHash: $id, packagePath: $shortUri}';
  }

  @override
  Map<String, dynamic> toJson() {
    return {'id': id, 'shortUri': shortUri.toString(), 'uri': uri.toString()};
  }

  factory FileAsset.fromJson(Map<String, dynamic> json) {
    return FileAsset(
      file: File.fromUri(Uri.parse(json['uri'] as String)),
      shortUri: Uri.parse(json['shortUri'] as String),
      id: json['id'] as String,
    );
  }

  @override
  String? get packageName {
    return switch (shortUri.scheme) {
      'dart' => 'dart',
      'package' || 'asset' => shortUri.pathSegments.firstOrNull,
      _ => null,
    };
  }

  @override
  Uri uriWithExtension(String ext) {
    return uri.replace(path: p.withoutExtension(uri.path) + ext);
  }

  @override
  void safeDelete() {
    try {
      if (existsSync()) {
        file.deleteSync(recursive: true);
      }
    } catch (e) {
      final stack = e is Error ? e.stackTrace : StackTrace.current;
      Logger.error('Error deleting file ${file.path}', stackTrace: stack);
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FileAsset &&
          runtimeType == other.runtimeType &&
          uri == other.uri &&
          id == other.id &&
          shortUri == other.shortUri;

  @override
  int get hashCode => uri.hashCode ^ id.hashCode ^ shortUri.hashCode;
}
