import 'dart:typed_data';
import 'package:xxh3/xxh3.dart';
import 'package:lean_builder/src/resolvers/file_asset.dart';

class StringSrc implements AssetSrc {
  StringSrc(this.content, {this.uriString = 'package:root/path.dart'});

  final String uriString;

  @override
  late final String id = xxh3String(Uint8List.fromList(uriString.codeUnits));

  @override
  late final Uri uri = Uri.parse(uriString);

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

  @override
  Uri get shortUri => uri;
}
