import 'package:lean_builder/src/asset/package_file_resolver.dart';
import 'package:lean_builder/src/graph/assets_graph.dart';
import 'package:lean_builder/src/graph/symbols_scanner.dart';
import 'package:lean_builder/src/resolvers/resolver.dart';
import 'package:lean_builder/src/resolvers/parsed_units_cache.dart';
import 'package:test/test.dart';

import '../scanner/string_asset_src.dart';

void main() {
  late PackageFileResolver fileResolver;
  SymbolsScanner? scanner;
  Resolver? resolver;

  setUpAll(() {
    final packageToPath = {PackageFileResolver.dartSdk: 'path/to/sdk', 'root': 'path/to/root'};
    fileResolver = PackageFileResolverImpl(packageToPath, packagesHash: '', rootPackage: 'root');
  });

  setUp(() {
    final AssetsGraph graph = AssetsGraph('hash');
    scanner = SymbolsScanner(graph, fileResolver);
    resolver = Resolver(graph, fileResolver, SourceParser());
  });

  test('should resolve simple class element', () {
    final asset = StringAsset('class Foo {}');
    scanner!.scan(asset);
    final library = resolver!.resolveLibrary(asset);
    expect(library.getClass('Foo'), isNotNull);
  });

  test('should resolve abstract class element', () {
    final asset = StringAsset('abstract class Foo {}');
    scanner!.scan(asset);
    final library = resolver!.resolveLibrary(asset);
    final classElement = library.getClass('Foo');
    expect(classElement, isNotNull);
    expect(classElement!.name, 'Foo');
    expect(classElement.hasAbstract, isTrue);
    expect(classElement.hasFinal, isFalse);
    expect(classElement.hasBase, isFalse);
    expect(classElement.hasInterface, isFalse);
    expect(classElement.isMixinClass, isFalse);
    expect(classElement.hasSealedKeyword, isFalse);
    expect(classElement.isConstructable, isFalse);
    expect(classElement.isMixinApplication, isFalse);
  });

  test('should resolve final class element', () {
    final asset = StringAsset('final class Foo {}');
    scanner!.scan(asset);
    final library = resolver!.resolveLibrary(asset);
    final classElement = library.getClass('Foo');
    expect(classElement, isNotNull);
    expect(classElement!.hasAbstract, isFalse);
    expect(classElement.hasFinal, isTrue);
    expect(classElement.hasBase, isFalse);
    expect(classElement.hasInterface, isFalse);
    expect(classElement.isMixinClass, isFalse);
    expect(classElement.hasSealedKeyword, isFalse);
    expect(classElement.isConstructable, isTrue);
    expect(classElement.isMixinApplication, isFalse);
  });

  test('should resolve base class element', () {
    final asset = StringAsset('base class Foo {}');
    scanner!.scan(asset);
    final library = resolver!.resolveLibrary(asset);
    final classElement = library.getClass('Foo');
    expect(classElement, isNotNull);
    expect(classElement!.hasAbstract, isFalse);
    expect(classElement.hasFinal, isFalse);
    expect(classElement.hasBase, isTrue);
    expect(classElement.hasInterface, isFalse);
    expect(classElement.isMixinClass, isFalse);
    expect(classElement.hasSealedKeyword, isFalse);
    expect(classElement.isConstructable, isTrue);
    expect(classElement.isMixinApplication, isFalse);
  });

  test('should resolve interface class element', () {
    final asset = StringAsset('interface class Foo {}');
    scanner!.scan(asset);
    final library = resolver!.resolveLibrary(asset);
    final classElement = library.getClass('Foo');
    expect(classElement, isNotNull);
    expect(classElement!.hasAbstract, isFalse);
    expect(classElement.hasFinal, isFalse);
    expect(classElement.hasBase, isFalse);
    expect(classElement.hasInterface, isTrue);
    expect(classElement.isMixinClass, isFalse);
    expect(classElement.hasSealedKeyword, isFalse);
    expect(classElement.isConstructable, isTrue);
    expect(classElement.isMixinApplication, isFalse);
  });

  test('should resolve mixin class element', () {
    final asset = StringAsset('mixin class Foo {}');
    scanner!.scan(asset);
    final library = resolver!.resolveLibrary(asset);
    final classElement = library.getClass('Foo');
    expect(classElement, isNotNull);
    expect(classElement!.hasAbstract, isFalse);
    expect(classElement.hasFinal, isFalse);
    expect(classElement.hasBase, isFalse);
    expect(classElement.hasInterface, isFalse);
    expect(classElement.isMixinClass, isTrue);
    expect(classElement.hasSealedKeyword, isFalse);
    expect(classElement.isConstructable, isTrue);
    expect(classElement.isMixinApplication, isFalse);
  });

  test('should resolve sealed class element', () {
    final asset = StringAsset('sealed class Foo {}');
    scanner!.scan(asset);
    final library = resolver!.resolveLibrary(asset);
    final classElement = library.getClass('Foo');
    expect(classElement, isNotNull);
    expect(classElement!.hasAbstract, isFalse);
    expect(classElement.hasSealedKeyword, isTrue);
    expect(classElement.hasFinal, isFalse);
    expect(classElement.hasBase, isFalse);
    expect(classElement.hasInterface, isFalse);
    expect(classElement.isMixinClass, isFalse);
    expect(classElement.isConstructable, isFalse);
    expect(classElement.isMixinApplication, isFalse);
  });

  test('should resolve mixin application class element', () {
    final asset = StringAsset('''
        class Bar {}
        mixin Baz {}
        class Foo = Bar with Baz;
    ''');
    scanner!.scan(asset);
    final library = resolver!.resolveLibrary(asset);
    final classElement = library.getClass('Foo');
    expect(classElement, isNotNull);
    expect(classElement!.hasSealedKeyword, isFalse);
    expect(classElement.hasAbstract, isFalse);
    expect(classElement.hasFinal, isFalse);
    expect(classElement.hasBase, isFalse);
    expect(classElement.hasInterface, isFalse);
    expect(classElement.isMixinClass, isFalse);
    expect(classElement.isConstructable, isTrue);
    expect(classElement.isMixinApplication, isTrue);
  });

  test('should resolve abstract interface class element', () {
    final asset = StringAsset('abstract interface class Foo {}');
    scanner!.scan(asset);
    final library = resolver!.resolveLibrary(asset);
    final classElement = library.getClass('Foo');
    expect(classElement, isNotNull);
    expect(classElement!.name, 'Foo');
    expect(classElement.hasAbstract, isTrue);
    expect(classElement.hasFinal, isFalse);
    expect(classElement.hasBase, isFalse);
    expect(classElement.hasInterface, isTrue);
    expect(classElement.isMixinClass, isFalse);
    expect(classElement.hasSealedKeyword, isFalse);
    expect(classElement.isConstructable, isFalse);
    expect(classElement.isMixinApplication, isFalse);
  });

  test('should resolve abstract final class element', () {
    final asset = StringAsset('abstract final class Foo {}');
    scanner!.scan(asset);
    final library = resolver!.resolveLibrary(asset);
    final classElement = library.getClass('Foo');
    expect(classElement, isNotNull);
    expect(classElement!.name, 'Foo');
    expect(classElement.hasAbstract, isTrue);
    expect(classElement.hasFinal, isTrue);
    expect(classElement.hasBase, isFalse);
    expect(classElement.hasInterface, isFalse);
    expect(classElement.isMixinClass, isFalse);
    expect(classElement.hasSealedKeyword, isFalse);
    expect(classElement.isConstructable, isFalse);
    expect(classElement.isMixinApplication, isFalse);
  });

  test('should resolve abstract mixin class element', () {
    final asset = StringAsset('abstract mixin class Foo {}');
    scanner!.scan(asset);
    final library = resolver!.resolveLibrary(asset);
    final classElement = library.getClass('Foo');
    expect(classElement, isNotNull);
    expect(classElement!.name, 'Foo');
    expect(classElement.hasAbstract, isTrue);
    expect(classElement.hasFinal, isFalse);
    expect(classElement.hasBase, isFalse);
    expect(classElement.hasInterface, isFalse);
    expect(classElement.isMixinClass, true);
    expect(classElement.hasSealedKeyword, false);
    expect(classElement.isConstructable, false);
    expect(classElement.isMixinApplication, false);
  });

  test('should resolve class with super class', () {
    final asset = StringAsset('''
        class Bar {}
        class Foo extends Bar {}
    ''');
    scanner!.scan(asset);
    final library = resolver!.resolveLibrary(asset);
    final classElement = library.getClass('Foo');
    expect(classElement, isNotNull);
    expect(classElement!.superType, library.getClass('Bar')!.thisType);
  });

  test('should resolve class with super interfaces', () {
    final asset = StringAsset('''
         class Bar {}
         class Baz {}
         class Foo implements Bar, Baz {}
    ''');
    scanner!.scan(asset);
    final library = resolver!.resolveLibrary(asset);
    final classElement = library.getClass('Foo');
    expect(classElement, isNotNull);
    expect(classElement!.interfaces, [library.getClass('Bar')!.thisType, library.getClass('Baz')!.thisType]);
  });

  test('should resolve class with mixins', () {
    final asset = StringAsset('''
        mixin Bar {}
        mixin Baz {}
        class Foo with Bar, Baz {}
    ''');
    scanner!.scan(asset);
    final library = resolver!.resolveLibrary(asset);
    final classElement = library.getClass('Foo');
    expect(classElement, isNotNull);
    expect(classElement!.mixins, [library.getMixin('Bar')!.thisType, library.getMixin('Baz')!.thisType]);
  });
}
