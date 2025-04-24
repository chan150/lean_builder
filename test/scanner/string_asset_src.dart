import 'dart:convert';
import 'dart:typed_data';
import 'package:lean_builder/src/asset/asset.dart';
import 'package:path/path.dart' as p;
import 'package:xxh3/xxh3.dart';

class StringAsset implements Asset {
  StringAsset(this.content, {this.uriString = 'package:root/path.dart'});

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
  String readAsStringSync({Encoding encoding = utf8}) {
    return content;
  }

  @override
  bool existsSync() => true;

  @override
  Uri get shortUri => uri;

  @override
  String? get packageName {
    final segments = uri.pathSegments;
    if (segments.isEmpty) return null;
    return segments[0];
  }

  @override
  Uri uriWithExtension(String ext) {
    return uri.replace(path: p.withoutExtension(uri.path) + ext);
  }

  @override
  Map<String, dynamic> toJson() {
    return {'id': id, 'shortUri': shortUri.toString(), 'uri': uri.toString(), 'content': content};
  }

  @override
  void safeDelete() {
    // No-op for StringAsset
  }
}
