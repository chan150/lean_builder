import 'package:lean_builder/src/asset/package_file_resolver.dart';
import 'package:lean_builder/src/graph/assets_graph.dart';
import 'package:lean_builder/src/graph/assets_scanner.dart';
import 'package:lean_builder/src/resolvers/resolver.dart';
import 'package:lean_builder/src/resolvers/parsed_units_cache.dart';
import 'package:test/test.dart';

import '../scanner/string_asset_src.dart';

void main() {
  late PackageFileResolver fileResolver;
  AssetsScanner? scanner;
  Resolver? resolver;

  setUpAll(() {
    fileResolver = PackageFileResolver.forRoot();
  });

  setUp(() {
    final AssetsGraph graph = AssetsGraph('hash');
    scanner = AssetsScanner(graph, fileResolver);
    resolver = Resolver(graph, fileResolver, SourceParser());
  });

  test('should resolve simple mixin element', () {
    final asset = StringAsset('mixin Foo {}');
    scanner!.scan(asset);
    final library = resolver!.resolveLibrary(asset);
    final mixinElement = library.getMixin('Foo');
    expect(mixinElement, isNotNull);
    expect(mixinElement!.isBase, isFalse);
    expect(mixinElement.superclassConstraints, isEmpty);
  });

  test('should resolve base mixin element', () {
    final asset = StringAsset('base mixin Foo {}');
    scanner!.scan(asset);
    final library = resolver!.resolveLibrary(asset);
    final mixinElement = library.getMixin('Foo');
    expect(mixinElement, isNotNull);
    expect(mixinElement!.isBase, isTrue);
    expect(mixinElement.superclassConstraints, isEmpty);
  });

  test('should resolve mixin with superclassConstraints', () {
    final asset = StringAsset('''
      class Bar {}
      class Baz {}
      mixin Foo on Bar, Baz {}
    ''');
    scanner!.scan(asset);
    final library = resolver!.resolveLibrary(asset);
    final mixinElement = library.getMixin('Foo');
    expect(mixinElement, isNotNull);
    expect(mixinElement!.superclassConstraints, library.classes.map((e) => e.thisType));
  });
}
