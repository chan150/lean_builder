import 'package:lean_builder/src/asset/package_file_resolver.dart';
import 'package:lean_builder/src/element/element.dart';
import 'package:lean_builder/src/graph/assets_graph.dart';
import 'package:lean_builder/src/graph/references_scanner.dart';
import 'package:lean_builder/src/resolvers/resolver.dart';
import 'package:lean_builder/src/resolvers/source_parser.dart';
import 'package:test/test.dart';

import '../scanner/string_asset_src.dart';

void main() {
  late PackageFileResolver fileResolver;
  ReferencesScanner? scanner;
  ResolverImpl? resolver;

  setUpAll(() {
    fileResolver = PackageFileResolver.forRoot();
  });

  setUp(() {
    final AssetsGraph graph = AssetsGraph('hash');
    scanner = ReferencesScanner(graph, fileResolver);
    resolver = ResolverImpl(graph, fileResolver, SourceParser());
  });

  test('should resolve simple mixin element', () {
    final StringAsset asset = StringAsset('mixin Foo {}');
    scanner!.scan(asset);
    final LibraryElement library = resolver!.resolveLibrary(asset);
    final MixinElementImpl? mixinElement = library.getMixin('Foo');
    expect(mixinElement, isNotNull);
    expect(mixinElement!.isBase, isFalse);
    expect(mixinElement.superclassConstraints, isEmpty);
  });

  test('should resolve base mixin element', () {
    final StringAsset asset = StringAsset('base mixin Foo {}');
    scanner!.scan(asset);
    final LibraryElement library = resolver!.resolveLibrary(asset);
    final MixinElementImpl? mixinElement = library.getMixin('Foo');
    expect(mixinElement, isNotNull);
    expect(mixinElement!.isBase, isTrue);
    expect(mixinElement.superclassConstraints, isEmpty);
  });

  test('should resolve mixin with superclassConstraints', () {
    final StringAsset asset = StringAsset('''
      class Bar {}
      class Baz {}
      mixin Foo on Bar, Baz {}
    ''');
    scanner!.scan(asset);
    final LibraryElement library = resolver!.resolveLibrary(asset);
    final MixinElementImpl? mixinElement = library.getMixin('Foo');
    expect(mixinElement, isNotNull);
    expect(
      mixinElement!.superclassConstraints,
      library.classes.map((ClassElementImpl e) => e.thisType),
    );
  });
}
