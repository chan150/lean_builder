import 'package:lean_builder/src/asset/package_file_resolver.dart';
import 'package:lean_builder/src/element/element.dart';
import 'package:lean_builder/src/graph/assets_graph.dart';
import 'package:lean_builder/src/graph/assets_scanner.dart';
import 'package:lean_builder/src/resolvers/constant/constant.dart';
import 'package:lean_builder/src/resolvers/resolver.dart';
import 'package:lean_builder/src/resolvers/parsed_units_cache.dart';
import 'package:test/test.dart';

import '../scanner/string_asset_src.dart';
import '../utils/test_utils.dart';

void main() {
  PackageFileResolverImpl? fileResolver;
  AssetsScanner? scanner;
  ResolverImpl? resolver;

  setUp(() {
    fileResolver = PackageFileResolver.forRoot() as PackageFileResolverImpl;
    final AssetsGraph graph = AssetsGraph('hash');
    scanner = AssetsScanner(graph, fileResolver!);
    resolver = ResolverImpl(graph, fileResolver!, SourceParser());
  });

  test('should resolve simple enum element', () {
    final asset = StringAsset('enum Foo {item;}');
    scanner!.scan(asset);
    final library = resolver!.resolveLibrary(asset);
    final enumElement = library.getEnum('Foo');
    expect(enumElement, isNotNull);
  });

  test('should resolve enum with implements clause', () {
    final asset = StringAsset('''
     class Bar {}
     enum Foo implements Bar {item;}
    ''');
    scanner!.scan(asset);
    final library = resolver!.resolveLibrary(asset);
    final enumElement = library.getEnum('Foo');
    expect(enumElement, isNotNull);
    expect(enumElement!.interfaces, [library.getClass('Bar')!.thisType]);
  });

  test('should resolve enum with mixin clause', () {
    final asset = StringAsset('''
     class Bar {}
     enum Foo with Bar {enum1;}
    ''');
    scanner!.scan(asset);
    final library = resolver!.resolveLibrary(asset);
    final enumElement = library.getEnum('Foo');
    expect(enumElement, isNotNull);
    expect(enumElement!.mixins, [library.getClass('Bar')!.thisType]);
  });

  test('should resolve enum with mixin and implements clause', () {
    final asset = StringAsset('''
      class Bar {}
      mixin Baz {}
      enum Foo with Baz implements Bar { enum1 }
    ''');
    scanner!.scan(asset);
    final library = resolver!.resolveLibrary(asset);
    final enumElement = library.getEnum('Foo');
    expect(enumElement, isNotNull);
    expect(enumElement!.interfaces, [library.getClass('Bar')!.thisType]);
    expect(enumElement.mixins, [library.getMixin('Baz')!.thisType]);
  });

  test('should resolve enum with annotations', () {
    final annotationAsset = StringAsset('''
      class Bar {
        const Bar();
      }
    ''', uriString: 'package:bar/bar.dart');

    final asset = StringAsset('''
      import 'package:bar/bar.dart';
      @Bar()
      enum Foo { enum1 }
    ''');

    fileResolver!.registerAsset(asset);
    fileResolver!.registerAsset(annotationAsset, relativeTo: asset);
    scanner!.scan(annotationAsset);
    scanner!.scan(asset);
    final library = resolver!.resolveLibrary(asset);
    final annotationLibrary = resolver!.resolveLibrary(annotationAsset);
    final enumElement = library.getEnum('Foo');
    expect(enumElement, isNotNull);
    expect(enumElement!.metadata.length, 1);
    expect(enumElement.metadata[0].type, annotationLibrary.getClass('Bar')!.thisType);
  });

  test('should resolve enum with fields', () {
    final asset = StringAsset('''
      enum Foo { enum1, enum2 }
    ''');
    scanner!.scan(asset);
    final library = resolver!.resolveLibrary(asset);
    final enumElement = library.getEnum('Foo');
    expect(enumElement, isNotNull);
    expect(enumElement!.fields.length, 2);
    expect(enumElement.fields[0].name, 'enum1');
    expect(enumElement.fields[1].name, 'enum2');
  });

  test('should resolve enum with no arguments', () {
    final asset = StringAsset('''
      enum Foo { item1; }
    ''');
    scanner!.scan(asset);

    final library = resolver!.resolveLibrary(asset);
    final enumElement = library.getEnum('Foo');
    expect(enumElement, isNotNull);
    expect(enumElement!.fields[0].constantValue, isNull);
  });

  test('should resolve enum with arguments', () {
    final asset = StringAsset('''
      enum Foo { 
        enum1(1);
        final int value; 
        const Foo(this.value); 
      }
    ''');
    scanner!.registerAndScan(asset);
    scanDartSdk(scanner!);
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
    final asset = StringAsset('''
      enum Foo { 
        enum1(1, name: 'name', value: 2); 
        final int value;
        final String name;  
        const Foo(this.value, {this.name}); 
      }
    ''');
    scanner!.registerAndScan(asset);
    scanDartSdk(scanner!);
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
