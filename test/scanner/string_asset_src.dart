import 'dart:io';
import 'dart:typed_data';
import 'package:xxh3/xxh3.dart';
import 'package:lean_builder/src/resolvers/file_asset.dart';

class StringSrc extends AssetSrc {
  StringSrc(this.content, {String uri = 'package:root/path.dart'})
    : super(File(uri), Uri.parse(uri), xxh3String(Uint8List.fromList(uri.codeUnits)));

  final String content;

  @override
  Uint8List readAsBytesSync() {
    return Uint8List.fromList(content.codeUnits);
  }

  @override
  String readAsStringSync() {
    return content;
  }

  @override
  bool existsSync() => true;
}
