import 'dart:io';
import 'dart:typed_data';

import 'package:code_genie/src/resolvers/file_asset.dart';

class AssetFileMock extends AssetSrc {
  AssetFileMock(this.content, {String id = 'mock-test-hash'}) : super(File('mock/path'), Uri.parse('mock/path'), id);

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
