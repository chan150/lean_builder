import 'package:lean_builder/src/scanner/top_level_scanner.dart';

import '../scanner/string_asset_src.dart';
import 'dart:core';

final _dartCoreAssets = [
  StringSrc('class bool {}', uriString: 'dart:core/bool.dart'),
  StringSrc('class num {}', uriString: 'dart:core/num.dart'),
  StringSrc('class int extends num {}', uriString: 'dart:core/int.dart'),
  StringSrc('class double extends num {}', uriString: 'dart:core/double.dart'),
  StringSrc('class String {}', uriString: 'dart:core/string.dart'),
  StringSrc('class Iterable<T> {}', uriString: 'dart:core/iterable.dart'),
  StringSrc('class List<T> extends Iterable<T>{}', uriString: 'dart:core/list.dart'),
  StringSrc('class Map<K, V> extends Iterable<MapEntry<K, V>> {}', uriString: 'dart:core/map.dart'),
  StringSrc('class Set<T> extends Iterable<T> {}', uriString: 'dart:core/set.dart'),
  StringSrc('class Null {}', uriString: 'dart:core/null.dart'),
  StringSrc('class Object {}', uriString: 'dart:core/object.dart'),
  StringSrc('class Type {}', uriString: 'dart:core/type.dart'),
  StringSrc('class Function {}', uriString: 'dart:core/function.dart'),
  StringSrc('class Symbol {}', uriString: 'dart:core/symbol.dart'),
  StringSrc('class DateTime {}', uriString: 'dart:core/date_time.dart'),
  StringSrc('class Duration {}', uriString: 'dart:core/duration.dart'),
  StringSrc('class Future<T> {}', uriString: 'dart:async/future.dart'),
  StringSrc('class Stream<T> {}', uriString: 'dart:async/stream.dart'),
];

void includeDartCoreAssets(TopLevelScanner scanner) {
  final buffer = StringBuffer();
  for (final asset in _dartCoreAssets) {
    scanner.scanFile(asset);
    buffer.writeln("export '${asset.shortUri}';");
  }
  final coreAsset = StringSrc(buffer.toString(), uriString: 'dart:core/core.dart');
  scanner.scanFile(coreAsset);
}
