import 'package:collection/collection.dart';

import '../resolvers/file_asset.dart';

class DirectiveStatement {
  final AssetFile asset;
  final List<String> show;
  final List<String> hide;

  DirectiveStatement({required this.asset, this.show = const [], this.hide = const []});

  bool shows(String identifier) => show.contains(identifier);

  bool hides(String identifier) => hide.contains(identifier);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DirectiveStatement &&
        other.asset == asset &&
        const ListEquality().equals(other.show, other.show) &&
        const ListEquality().equals(other.hide, other.hide);
  }

  @override
  int get hashCode => asset.hashCode ^ const ListEquality().hash(show) ^ const ListEquality().hash(hide);

  @override
  String toString() {
    return 'ExportStatement{path: $asset, show: $show, hide: $hide}';
  }
}
