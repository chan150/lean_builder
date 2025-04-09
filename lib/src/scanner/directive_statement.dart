import 'package:analyzer/dart/ast/token.dart';

import '../resolvers/file_asset.dart';

class DirectiveStatement {
  static const int library = 0;
  static const int import = 1;
  static const int export = 2;
  static const int part = 3;
  static const int partOf = 4;
  static const int partOfLibrary = 5;

  final int type;
  final AssetSrc asset;
  final List<String> show;
  final List<String> hide;
  final String? prefix;

  DirectiveStatement({
    required this.type,
    required this.asset,
    this.show = const [],
    this.hide = const [],
    this.prefix,
  });

  bool shows(String identifier) => show.contains(identifier);

  bool hides(String identifier) => hide.contains(identifier);

  @override
  String toString() {
    return 'ExportStatement{path: $asset, show: $show, hide: $hide}';
  }
}
