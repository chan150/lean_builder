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
    fileResolver = PackageFileResolverImpl(packageToPath, packageToPath.map((k, v) => MapEntry(v, k)), '', 'root');
  });

  setUp(() {
    final AssetsGraph graph = AssetsGraph('hash');
    scanner = TopLevelScanner(graph, fileResolver);
    resolver = ElementResolver(graph, fileResolver, SrcParser());
  });

  test('should resolve simple enum element', () {
    final asset = StringSrc('enum Foo {item;}');
    scanner!.scanFile(asset);
    final library = resolver!.resolveLibrary(asset);
    final enumElement = library.getEnum('Foo');
    expect(enumElement, isNotNull);
  });

  test('should resolve enum with implements clause', () {
    final asset = StringSrc('''
     class Bar {}
     enum Foo implements Bar {item;}
    ''');
    scanner!.scanFile(asset);
    final library = resolver!.resolveLibrary(asset);
    final enumElement = library.getEnum('Foo');
    expect(enumElement, isNotNull);
    expect(enumElement!.interfaces, [library.getClass('Bar')!.thisType]);
  });

  test('should resolve enum with mixin clause', () {
    final asset = StringSrc('''
     class Bar {}
     enum Foo with Bar {item;}
    ''');
    scanner!.scanFile(asset);
    final library = resolver!.resolveLibrary(asset);
    final enumElement = library.getEnum('Foo');
    expect(enumElement, isNotNull);
    expect(enumElement!.mixins, [library.getClass('Bar')!.thisType]);
  });

  test('should resolve enum with mixin and implements clause', () {
    final asset = StringSrc('''
      class Bar {}
      mixin Baz {}
      enum Foo with Baz implements Bar { item }
    ''');
    scanner!.scanFile(asset);
    final library = resolver!.resolveLibrary(asset);
    final enumElement = library.getEnum('Foo');
    expect(enumElement, isNotNull);
    expect(enumElement!.interfaces, [library.getClass('Bar')!.thisType]);
    expect(enumElement.mixins, [library.getMixin('Baz')!.thisType]);
  });

  test('should resolve enum with fields', () {
    final asset = StringSrc('''
      enum Foo { item1, item2 }
    ''');
    scanner!.scanFile(asset);
    final library = resolver!.resolveLibrary(asset);
    final enumElement = library.getEnum('Foo');
    expect(enumElement, isNotNull);
    expect(enumElement!.fields.length, 2);
    expect(enumElement.fields[0].name, 'item1');
    expect(enumElement.fields[1].name, 'item2');
  });
}
