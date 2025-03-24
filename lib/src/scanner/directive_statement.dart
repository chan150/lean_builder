import 'package:analyzer/dart/ast/token.dart';

import '../resolvers/file_asset.dart';

class DirectiveStatement {
  final TokenType type;
  final AssetFile asset;
  final List<String> show;
  final List<String> hide;

  DirectiveStatement({required this.type, required this.asset, this.show = const [], this.hide = const []});

  bool shows(String identifier) => show.contains(identifier);

  bool hides(String identifier) => hide.contains(identifier);

  @override
  String toString() {
    return 'ExportStatement{path: $asset, show: $show, hide: $hide}';
  }
}
