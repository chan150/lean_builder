import 'package:analyzer/dart/element/type.dart';
import 'package:lean_builder/builder.dart';
import 'package:lean_builder/element.dart';
import 'package:lean_builder/src/asset/package_file_resolver.dart';
import 'package:lean_builder/src/graph/assets_graph.dart';
import 'package:lean_builder/src/graph/assets_scanner.dart';
import 'package:lean_builder/src/resolvers/parsed_units_cache.dart';
import 'package:lean_builder/src/type/type.dart';
import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';

import '../scanner/string_asset_src.dart';
import '../utils/test_utils.dart';

void main() {
  late AssetsScanner scanner;
  late AssetsGraph assetsGraph;
  late Resolver resolver;
  setUp(() {
    final fileResolver = PackageFileResolver.forRoot();
    assetsGraph = AssetsGraph(fileResolver.packagesHash);
    scanner = AssetsScanner(assetsGraph, fileResolver);
    resolver = Resolver(assetsGraph, fileResolver, SourceParser());
  });

  test('Should evaluate const fields with literal values', () {
    final asset = StringAsset('''
     enum Enum {enum1, enum2;}
    
      class Foo {
        static const int a = 1;
        static const double b = 2.0;
        static const String c = 'hello';
        static const bool d = true;
        static const Type g = int;
        static const Enum h = Enum.enum2;
        static const n = null;
        static const List<int> e = [1, 2, 3];
        static const Set i = {1, 'str', 3};
        static const Map<String, int> f = {'one': 1, 'two': 2};
        static const bool k = false;
        static const num l = 1.0;
      }
    ''', uriString: 'package:lean_builder/path.dart');
    scanDartSdk(scanner);
    scanner.registerAndScan(asset);
    final library = resolver.resolveLibrary(asset);
    final classElement = library.getClass('Foo');

    expect(classElement, isNotNull);
    expect(classElement!.getField('a')!.constantValue, isA<ConstInt>().having((c) => c.value, 'value', 1));
    expect(classElement.getField('b')!.constantValue, isA<ConstDouble>().having((c) => c.value, 'value', 2.0));
    expect(classElement.getField('c')!.constantValue, isA<ConstString>().having((c) => c.value, 'value', 'hello'));
    expect(classElement.getField('d')!.constantValue, isA<ConstBool>().having((c) => c.value, 'value', true));
    expect(classElement.getField('g')!.constantValue, isA<ConstType>());
    expect(classElement.getField('n')!.constantValue, isNull);

    expect(
      classElement.getField('e')!.constantValue,
      isA<ConstList>().having((c) => c.value, 'value', [ConstInt(1), ConstInt(2), ConstInt(3)]),
    );
    expect(
      classElement.getField('i')!.constantValue,
      isA<ConstSet>().having((c) => c.value, 'value', {ConstInt(1), ConstString('str'), ConstInt(3)}),
    );

    expect(
      classElement.getField('f')!.constantValue,
      isA<ConstMap>().having((c) => c.value, 'value', {
        ConstString('one'): ConstInt(1),
        ConstString('two'): ConstInt(2),
      }),
    );

    expect(
      classElement.getField('h')!.constantValue,
      isA<ConstEnumValue>()
          .having((c) => c.value, 'value', 'enum2')
          .having((c) => c.literalValue, 'literalValue', 'Enum.enum2')
          .having((c) => c.index, 'index', 1),
    );
    expect(classElement.getField('k')!.constantValue, isA<ConstBool>().having((c) => c.value, 'value', false));
    expect(classElement.getField('l')!.constantValue, isA<ConstDouble>().having((c) => c.value, 'value', 1.0));
  });
}
