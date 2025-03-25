import 'dart:io';
import 'dart:typed_data';

import 'package:code_genie/src/resolvers/file_asset.dart';

class AssetFileMock extends AssetFile {
  AssetFileMock(this.content) : super(File('mock/path'), Uri.parse('mock/path'), 'mock-test-hash', false);

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
