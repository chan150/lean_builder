import 'package:collection/collection.dart';

class DirectiveStatement {
  final Uri uri;
  final List<String> show;
  final List<String> hide;

  DirectiveStatement({required this.uri, this.show = const [], this.hide = const []});

  bool shows(String identifier) => show.contains(identifier);

  bool hides(String identifier) => hide.contains(identifier);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DirectiveStatement &&
        other.uri == uri &&
        const ListEquality().equals(other.show, other.show) &&
        const ListEquality().equals(other.hide, other.hide);
  }

  @override
  int get hashCode => uri.hashCode ^ const ListEquality().hash(show) ^ const ListEquality().hash(hide);

  @override
  String toString() {
    return 'ExportStatement{path: $uri, show: $show, hide: $hide}';
  }
}
