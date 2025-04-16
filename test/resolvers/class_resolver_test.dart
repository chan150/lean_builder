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

  test('should resolve simple class element', () {
    final asset = StringSrc('class Foo {}');
    scanner!.scanFile(asset);
    final library = resolver!.resolveLibrary(asset);
    expect(library.getClass('Foo'), isNotNull);
  });

  test('should resolve abstract class element', () {
    final asset = StringSrc('abstract class Foo {}');
    scanner!.scanFile(asset);
    final library = resolver!.resolveLibrary(asset);
    final classElement = library.getClass('Foo');
    expect(classElement, isNotNull);
    expect(classElement!.name, 'Foo');
    expect(classElement.isAbstract, isTrue);
    expect(classElement.isFinal, isFalse);
    expect(classElement.isBase, isFalse);
    expect(classElement.isInterface, isFalse);
    expect(classElement.isMixinClass, isFalse);
    expect(classElement.isSealed, isFalse);
    expect(classElement.isConstructable, isFalse);
    expect(classElement.isMixinApplication, isFalse);
  });

  test('should resolve final class element', () {
    final asset = StringSrc('final class Foo {}');
    scanner!.scanFile(asset);
    final library = resolver!.resolveLibrary(asset);
    final classElement = library.getClass('Foo');
    expect(classElement, isNotNull);
    expect(classElement!.isAbstract, isFalse);
    expect(classElement.isFinal, isTrue);
    expect(classElement.isBase, isFalse);
    expect(classElement.isInterface, isFalse);
    expect(classElement.isMixinClass, isFalse);
    expect(classElement.isSealed, isFalse);
    expect(classElement.isConstructable, isTrue);
    expect(classElement.isMixinApplication, isFalse);
  });

  test('should resolve base class element', () {
    final asset = StringSrc('base class Foo {}');
    scanner!.scanFile(asset);
    final library = resolver!.resolveLibrary(asset);
    final classElement = library.getClass('Foo');
    expect(classElement, isNotNull);
    expect(classElement!.isAbstract, isFalse);
    expect(classElement.isFinal, isFalse);
    expect(classElement.isBase, isTrue);
    expect(classElement.isInterface, isFalse);
    expect(classElement.isMixinClass, isFalse);
    expect(classElement.isSealed, isFalse);
    expect(classElement.isConstructable, isTrue);
    expect(classElement.isMixinApplication, isFalse);
  });

  test('should resolve interface class element', () {
    final asset = StringSrc('interface class Foo {}');
    scanner!.scanFile(asset);
    final library = resolver!.resolveLibrary(asset);
    final classElement = library.getClass('Foo');
    expect(classElement, isNotNull);
    expect(classElement!.isAbstract, isFalse);
    expect(classElement.isFinal, isFalse);
    expect(classElement.isBase, isFalse);
    expect(classElement.isInterface, isTrue);
    expect(classElement.isMixinClass, isFalse);
    expect(classElement.isSealed, isFalse);
    expect(classElement.isConstructable, isTrue);
    expect(classElement.isMixinApplication, isFalse);
  });

  test('should resolve mixin class element', () {
    final asset = StringSrc('mixin class Foo {}');
    scanner!.scanFile(asset);
    final library = resolver!.resolveLibrary(asset);
    final classElement = library.getClass('Foo');
    expect(classElement, isNotNull);
    expect(classElement!.isAbstract, isFalse);
    expect(classElement.isFinal, isFalse);
    expect(classElement.isBase, isFalse);
    expect(classElement.isInterface, isFalse);
    expect(classElement.isMixinClass, isTrue);
    expect(classElement.isSealed, isFalse);
    expect(classElement.isConstructable, isTrue);
    expect(classElement.isMixinApplication, isFalse);
  });

  test('should resolve sealed class element', () {
    final asset = StringSrc('sealed class Foo {}');
    scanner!.scanFile(asset);
    final library = resolver!.resolveLibrary(asset);
    final classElement = library.getClass('Foo');
    expect(classElement, isNotNull);
    expect(classElement!.isAbstract, isTrue);
    expect(classElement.isSealed, isTrue);
    expect(classElement.isFinal, isFalse);
    expect(classElement.isBase, isFalse);
    expect(classElement.isInterface, isFalse);
    expect(classElement.isMixinClass, isFalse);
    expect(classElement.isConstructable, isFalse);
    expect(classElement.isMixinApplication, isFalse);
  });

  test('should resolve mixin application class element', () {
    final asset = StringSrc('''
        class Bar {}
        mixin Baz {}
        class Foo = Bar with Baz;
    ''');
    scanner!.scanFile(asset);
    final library = resolver!.resolveLibrary(asset);
    final classElement = library.getClass('Foo');
    expect(classElement, isNotNull);
    expect(classElement!.isSealed, isFalse);
    expect(classElement.isAbstract, isFalse);
    expect(classElement.isFinal, isFalse);
    expect(classElement.isBase, isFalse);
    expect(classElement.isInterface, isFalse);
    expect(classElement.isMixinClass, isFalse);
    expect(classElement.isConstructable, isTrue);
    expect(classElement.isMixinApplication, isTrue);
  });

  test('should resolve abstract interface class element', () {
    final asset = StringSrc('abstract interface class Foo {}');
    scanner!.scanFile(asset);
    final library = resolver!.resolveLibrary(asset);
    final classElement = library.getClass('Foo');
    expect(classElement, isNotNull);
    expect(classElement!.name, 'Foo');
    expect(classElement.isAbstract, isTrue);
    expect(classElement.isFinal, isFalse);
    expect(classElement.isBase, isFalse);
    expect(classElement.isInterface, isTrue);
    expect(classElement.isMixinClass, isFalse);
    expect(classElement.isSealed, isFalse);
    expect(classElement.isConstructable, isFalse);
    expect(classElement.isMixinApplication, isFalse);
  });

  test('should resolve abstract final class element', () {
    final asset = StringSrc('abstract final class Foo {}');
    scanner!.scanFile(asset);
    final library = resolver!.resolveLibrary(asset);
    final classElement = library.getClass('Foo');
    expect(classElement, isNotNull);
    expect(classElement!.name, 'Foo');
    expect(classElement.isAbstract, isTrue);
    expect(classElement.isFinal, isTrue);
    expect(classElement.isBase, isFalse);
    expect(classElement.isInterface, isFalse);
    expect(classElement.isMixinClass, isFalse);
    expect(classElement.isSealed, isFalse);
    expect(classElement.isConstructable, isFalse);
    expect(classElement.isMixinApplication, isFalse);
  });

  test('should resolve abstract mixin class element', () {
    final asset = StringSrc('abstract mixin class Foo {}');
    scanner!.scanFile(asset);
    final library = resolver!.resolveLibrary(asset);
    final classElement = library.getClass('Foo');
    expect(classElement, isNotNull);
    expect(classElement!.name, 'Foo');
    expect(classElement.isAbstract, isTrue);
    expect(classElement.isFinal, isFalse);
    expect(classElement.isBase, isFalse);
    expect(classElement.isInterface, isFalse);
    expect(classElement.isMixinClass, true);
    expect(classElement.isSealed, false);
    expect(classElement.isConstructable, false);
    expect(classElement.isMixinApplication, false);
  });

  test('should resolve class with super class', () {
    final asset = StringSrc('''
        class Bar {}
        class Foo extends Bar {}
    ''');
    scanner!.scanFile(asset);
    final library = resolver!.resolveLibrary(asset);
    final classElement = library.getClass('Foo');
    expect(classElement, isNotNull);
    expect(classElement!.superType, library.getClass('Bar')!.thisType);
  });

  test('should resolve class with super interfaces', () {
    final asset = StringSrc('''
         class Bar {}
         class Baz {}
         class Foo implements Bar, Baz {}
    ''');
    scanner!.scanFile(asset);
    final library = resolver!.resolveLibrary(asset);
    final classElement = library.getClass('Foo');
    expect(classElement, isNotNull);
    expect(classElement!.interfaces, [library.getClass('Bar')!.thisType, library.getClass('Baz')!.thisType]);
  });

  test('should resolve class with mixins', () {
    final asset = StringSrc('''
        mixin Bar {}
        mixin Baz {}
        class Foo with Bar, Baz {}
    ''');
    scanner!.scanFile(asset);
    final library = resolver!.resolveLibrary(asset);
    final classElement = library.getClass('Foo');
    expect(classElement, isNotNull);
    expect(classElement!.mixins, [library.getMixin('Bar')!.thisType, library.getMixin('Baz')!.thisType]);
  });
}
