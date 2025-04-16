import '../scanner/string_asset_src.dart';

final dartCoreAssets = [
  StringSrc('class bool {}', uri: 'dart:core/bool.dart'),
  StringSrc('class num {}', uri: 'dart:core/num.dart'),
  StringSrc('class int extends num {}', uri: 'dart:core/int.dart'),
  StringSrc('class double extends num {}', uri: 'dart:core/double.dart'),
  StringSrc('class String {}', uri: 'dart:core/string.dart'),
  StringSrc('class Iterable<T> {}', uri: 'dart:core/iterable.dart'),
  StringSrc('class List<T> extends Iterable<T>{}', uri: 'dart:core/list.dart'),
  StringSrc('class Map<K, V> extends Iterable<MapEntry<K, V>> {}', uri: 'dart:core/map.dart'),
  StringSrc('class Set<T> extends Iterable<T> {}', uri: 'dart:core/set.dart'),
  StringSrc('class Null {}', uri: 'dart:core/null.dart'),
  StringSrc('class Object {}', uri: 'dart:core/object.dart'),
  StringSrc('class Type {}', uri: 'dart:core/type.dart'),
  StringSrc('class Function {}', uri: 'dart:core/function.dart'),
  StringSrc('class Symbol {}', uri: 'dart:core/symbol.dart'),
  StringSrc('class DateTime {}', uri: 'dart:core/date_time.dart'),
  StringSrc('class Duration {}', uri: 'dart:core/duration.dart'),
  StringSrc('class Future<T> {}', uri: 'dart:async/future.dart'),
  StringSrc('class Stream<T> {}', uri: 'dart:async/stream.dart'),
];
