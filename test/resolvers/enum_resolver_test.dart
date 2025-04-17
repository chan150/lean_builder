import 'package:lean_builder/src/resolvers/constant/constant.dart';
import 'package:lean_builder/src/resolvers/element/element.dart';
import 'package:lean_builder/src/resolvers/element_resolver.dart';
import 'package:lean_builder/src/resolvers/package_file_resolver.dart';
import 'package:lean_builder/src/resolvers/parsed_units_cache.dart';
import 'package:lean_builder/src/scanner/assets_graph.dart';
import 'package:lean_builder/src/scanner/top_level_scanner.dart';
import 'package:test/test.dart';

import '../scanner/string_asset_src.dart';
import '../utils/mock_package_file_resolver.dart';
import 'dart_core_assets.dart';

void main() {
  late PackageFileResolver fileResolver;
  TopLevelScanner? scanner;
  ElementResolver? resolver;

  setUpAll(() {
    final packageToPath = {PackageFileResolver.dartSdk: 'path/to/sdk', 'root': 'path/to/root'};
    fileResolver = MockPackageFileResolver(packageToPath);
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
     enum Foo with Bar {enum1;}
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
      enum Foo with Baz implements Bar { enum1 }
    ''');
    scanner!.scanFile(asset);
    final library = resolver!.resolveLibrary(asset);
    final enumElement = library.getEnum('Foo');
    expect(enumElement, isNotNull);
    expect(enumElement!.interfaces, [library.getClass('Bar')!.thisType]);
    expect(enumElement.mixins, [library.getMixin('Baz')!.thisType]);
  });

  test('should resolve enum with annotations', () {
    final asset = StringSrc('''
      class Bar {
        const Bar();
      }
      @Bar()
      enum Foo { enum1 }
    ''');
    scanner!.scanFile(asset);
    final library = resolver!.resolveLibrary(asset);
    final enumElement = library.getEnum('Foo');
    expect(enumElement, isNotNull);
    expect(enumElement!.metadata.length, 1);
    expect(enumElement.metadata[0].type, library.getClass('Bar')!.thisType);
  });

  test('should resolve enum with fields', () {
    final asset = StringSrc('''
      enum Foo { enum1, enum2 }
    ''');
    scanner!.scanFile(asset);
    final library = resolver!.resolveLibrary(asset);
    final enumElement = library.getEnum('Foo');
    expect(enumElement, isNotNull);
    expect(enumElement!.fields.length, 2);
    expect(enumElement.fields[0].name, 'enum1');
    expect(enumElement.fields[1].name, 'enum2');
  });

  test('should resolve enum with no arguments', () {
    final asset = StringSrc('''
      enum Foo { item1; }
    ''');
    scanner!.scanFile(asset);

    final library = resolver!.resolveLibrary(asset);
    final enumElement = library.getEnum('Foo');
    expect(enumElement, isNotNull);
    expect(enumElement!.fields[0].constantValue, isNull);
  });

  test('should resolve enum with arguments', () {
    final asset = StringSrc('''
      enum Foo { 
        enum1(1);
        final int value; 
        const Foo(this.value); 
      }
    ''');
    scanner!.scanFile(asset);
    includeDartCoreAssets(scanner!);
    final library = resolver!.resolveLibrary(asset);
    final enumElement = library.getEnum('Foo');
    expect(enumElement, isNotNull);
    expect(enumElement!.constructors.length, 1);
    expect(enumElement.constructors[0].parameters[0], isA<ParameterElement>());
    final constantFields = enumElement.fields.where((field) => field.isEnumConstant);
    final constantObj = constantFields.first.constantValue;
    expect(constantObj, isA<ConstObject>());
    expect((constantObj as ConstObject).props, {'value': ConstInt(1)});
  });

  test('should resolve enum with named and optional positional arguments', () {
    final asset = StringSrc('''
      enum Foo { 
        enum1(1, name: 'name', value: 2); 
        
        final int value;
        final String name;  
        const Foo(this.value, {this.name}); 
      }
    ''');
    scanner!.scanFile(asset);
    includeDartCoreAssets(scanner!);
    final library = resolver!.resolveLibrary(asset);
    final enumElement = library.getEnum('Foo');
    expect(enumElement, isNotNull);
    final constantFields = enumElement!.fields.where((field) => field.isEnumConstant);

    expect(constantFields.length, 1);
    final constantObj = constantFields.first.constantValue;
    expect(constantObj, isA<ConstObject>());
    expect((constantObj as ConstObject).props, {'value': ConstInt(2), 'name': ConstString('name')});
  });
}
