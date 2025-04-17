import 'dart:io';
import 'dart:typed_data';

abstract class AssetSrc {
  String get id;

  Uri get shortUri;

  Uri get uri;

  Uint8List readAsBytesSync();

  String readAsStringSync();

  bool existsSync();

  factory AssetSrc(File file, Uri shortUri, String id) = FileAssetSrc;
}

class FileAssetSrc implements AssetSrc {
  final File file;

  @override
  final String id;

  @override
  final Uri shortUri;

  FileAssetSrc(this.file, this.shortUri, this.id);

  @override
  Uri get uri => file.uri;

  @override
  Uint8List readAsBytesSync() {
    return file.readAsBytesSync();
  }

  @override
  String readAsStringSync() {
    return file.readAsStringSync();
  }

  @override
  bool existsSync() => file.existsSync();

  @override
  String toString() {
    return 'FileAsset{file: $file, pathHash: $id, packagePath: $shortUri}';
  }
}
