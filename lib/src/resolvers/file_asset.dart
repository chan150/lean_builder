import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
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

  /// returns null if [shortUri] is not a package asset or it has empty segments
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
    if (shortUri.scheme != 'package') return null;
    final segments = shortUri.pathSegments;
    return segments.firstOrNull;
  }

  @override
  Uri uriWithExtension(String ext) {
    return uri.replace(path: p.withoutExtension(uri.path) + ext);
  }

  @override
  void safeDelete() {
    try {
      if (existsSync()) {
        file.deleteSync();
      }
    } catch (e) {
      print('Error deleting file: $e');
    }
  }
}
