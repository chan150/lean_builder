import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

abstract class Asset {
  String get id;

  Uri get shortUri;

  Uri get uri;

  Uint8List readAsBytesSync();

  String readAsStringSync({Encoding encoding = utf8});

  bool existsSync();

  factory Asset(File file, Uri shortUri, String id) = FileAsset;
}

class FileAsset implements Asset {
  final File file;

  @override
  final String id;

  @override
  final Uri shortUri;

  FileAsset(this.file, this.shortUri, this.id);

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
}
