import 'package:lean_builder/src/resolvers/element_resolver.dart';
import 'package:lean_builder/src/resolvers/package_file_resolver.dart';
import 'package:lean_builder/src/resolvers/parsed_units_cache.dart';
import 'package:lean_builder/src/scanner/assets_graph.dart';
import 'package:lean_builder/src/scanner/top_level_scanner.dart';
import 'package:test/test.dart';

import '../scanner/string_asset_src.dart';

void main() {
  late PackageFileResolver fileResolver;
  TopLevelScanner? scanner;
  ElementResolver? resolver;

  setUpAll(() {
    final packageToPath = {PackageFileResolver.dartSdk: 'path/to/sdk', 'root': 'path/to/root'};
    fileResolver = PackageFileResolverImpl(packageToPath, packagesHash: '', rootPackage: 'root');
  });

  setUp(() {
    final AssetsGraph graph = AssetsGraph('hash');
    scanner = TopLevelScanner(graph, fileResolver);
    resolver = ElementResolver(graph, fileResolver, SrcParser());
  });

  test('should resolve simple mixin element', () {
    final asset = StringSrc('mixin Foo {}');
    scanner!.scan(asset);
    final library = resolver!.resolveLibrary(asset);
    final mixinElement = library.getMixin('Foo');
    expect(mixinElement, isNotNull);
    expect(mixinElement!.isBase, isFalse);
    expect(mixinElement.superclassConstraints, isEmpty);
  });

  test('should resolve base mixin element', () {
    final asset = StringSrc('base mixin Foo {}');
    scanner!.scan(asset);
    final library = resolver!.resolveLibrary(asset);
    final mixinElement = library.getMixin('Foo');
    expect(mixinElement, isNotNull);
    expect(mixinElement!.isBase, isTrue);
    expect(mixinElement.superclassConstraints, isEmpty);
  });

  test('should resolve mixin with superclassConstraints', () {
    final asset = StringSrc('''
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
