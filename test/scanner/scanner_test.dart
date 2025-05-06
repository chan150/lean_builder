import 'package:lean_builder/src/asset/package_file_resolver.dart' show PackageFileResolverImpl;
import 'package:lean_builder/src/graph/assets_graph.dart' show AssetsGraph;
import 'package:lean_builder/src/graph/directive_statement.dart';
import 'package:lean_builder/src/graph/scan_results.dart';
import 'package:lean_builder/src/graph/assets_scanner.dart' show AssetsScanner;

import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';

import '../utils/test_utils.dart';
import 'string_asset_src.dart';

main() {
  late AssetsScanner scanner;
  late AssetsGraph assetsGraph;

  setUp(() {
    final fileResolver = PackageFileResolverImpl({'root': 'file:///root'}, packagesHash: '', rootPackage: 'root');
    assetsGraph = AssetsGraph(fileResolver.packagesHash);
    scanner = AssetsScanner(assetsGraph, fileResolver);
  });

  test('TopLevelScanner should scan a file with const variables', () {
    final file = StringAsset('''
    String stringVar = 'string';
    const int _privateConst = 42;
    final int finalInt = 42;
    const kPi = 3.14159;
    const inferredConst = 3.14159;
    const List<String> constants = ['A', 'B'];
    const Map<int, List<int>> kValue = _kValue; 
    ''');
    scanner.scan(file);
    final expected = [
      ['_privateConst', file.id, SymbolType.$variable.value],
      ['kPi', file.id, SymbolType.$variable.value],
      ['inferredConst', file.id, SymbolType.$variable.value],
      ['constants', file.id, SymbolType.$variable.value],
      ['kValue', file.id, SymbolType.$variable.value],
    ];
    expect(assetsGraph.identifiers, expected);
  });

  test('TopLevelScanner should ignore commented out identifiers', () {
    final file = StringAsset('''
    // constant kPi = 3.14159;
    // class Shape {}
    // void add(){}
    /* constant constInt = 42; */
    ''');
    scanner.scan(file);
    expect(assetsGraph.identifiers.isEmpty, true);
  });

  // member variables/methods should be ignored
  test('TopLevelScanner should ignore member variables and methods', () {
    final file = StringAsset('''
    class MyClass {
      static constant privateInt = 42;
      final int finalInt = 42;
      late final String lateString;
      void privateMethod() {}
      int get getter => 42;
      set setter(int value) {}
      abstract void abstractMethod();
    }
    ''');
    scanner.scan(file);
    expect(assetsGraph.identifiers.length, 1);
  });

  test('TopLevelScanner should scan a file with enums', () {
    final file = StringAsset('''
    enum Enum { red, green, blue }
    enum EnumWithImpl implements Logger { red, green, blue }
    ''');
    scanner.scan(file);
    final expected = [
      ['Enum', file.id, SymbolType.$enum.value],
      ['EnumWithImpl', file.id, SymbolType.$enum.value],
    ];
    expect(assetsGraph.identifiers, expected);
  });

  // typedef
  test('TopLevelScanner should scan a file with typedefs', () {
    final file = StringAsset('''
    typedef JsonMap = Map<String, dynamic>;
    typedef Record = (String key, dynamic value);
    typedef Callback = void Function(String);
    typedef GenericCallback<T> = void Function(T);
    typedef GenericCallback2<T, U> = void Function(T, U);
    typedef bool ElementPredicate<E>(E element);
    typedef Future<int> TypeName();
    typedef void ConsumerCallback<T>(T value);
    typedef NullableMap = Map<String, String?>;
    typedef FunctionFactory = void Function() Function(String);
    typedef Comparable<T extends num> = int Function(T, T);
    typedef ComplexRecord = ({String name, int age, List<String>? hobbies});
    typedef KeyValuePair<K extends Comparable<K>, V> = MapEntry<K, V>;
    typedef OptionalParams = void Function(int required, [String? optional]);
    typedef NamedParams = void Function({required String name, int? age});
    typedef JsonProcessor = void Function(JsonMap data);
    typedef Transformer<T, U> = U Function(T Function(T) processor, T input);
    ''');
    scanner.scan(file);
    final expected = [
      ['JsonMap', file.id, SymbolType.$typeAlias.value],
      ['Record', file.id, SymbolType.$typeAlias.value],
      ['Callback', file.id, SymbolType.$typeAlias.value],
      ['GenericCallback', file.id, SymbolType.$typeAlias.value],
      ['GenericCallback2', file.id, SymbolType.$typeAlias.value],
      ['ElementPredicate', file.id, SymbolType.$typeAlias.value],
      ['TypeName', file.id, SymbolType.$typeAlias.value],
      ['ConsumerCallback', file.id, SymbolType.$typeAlias.value],
      ['NullableMap', file.id, SymbolType.$typeAlias.value],
      ['FunctionFactory', file.id, SymbolType.$typeAlias.value],
      ['Comparable', file.id, SymbolType.$typeAlias.value],
      ['ComplexRecord', file.id, SymbolType.$typeAlias.value],
      ['KeyValuePair', file.id, SymbolType.$typeAlias.value],
      ['OptionalParams', file.id, SymbolType.$typeAlias.value],
      ['NamedParams', file.id, SymbolType.$typeAlias.value],
      ['JsonProcessor', file.id, SymbolType.$typeAlias.value],
      ['Transformer', file.id, SymbolType.$typeAlias.value],
    ];
    expect(assetsGraph.identifiers, expected);
  });

  test('TopLevelScanner should scan a file with extensions', () {
    final file = StringAsset('''
    extension StringExt on String {}
    extension ListExt<S> on List<S> {}
    extension type const TypeExt(double? offset) {}
    extension type TypeExt2(double? offset) {}
    ''');
    scanner.scan(file);
    final expected = [
      ['StringExt', file.id, SymbolType.$extension.value],
      ['ListExt', file.id, SymbolType.$extension.value],
      ['TypeExt', file.id, SymbolType.$extension.value],
      ['TypeExt2', file.id, SymbolType.$extension.value],
    ];
    expect(assetsGraph.identifiers, expected);
  });

  test('TopLevelScanner should scan a file with mixins', () {
    final file = StringAsset('''
    mixin Logger {
      void log(String msg) {}
    }
    mixin Logger2 on Logger {
      void log2(String msg) {}
    }
    ''');
    scanner.scan(file);
    final expected = [
      ['Logger', file.id, SymbolType.$mixin.value],
      ['Logger2', file.id, SymbolType.$mixin.value],
    ];
    expect(assetsGraph.identifiers, expected);
  });

  test('TopLevelScanner should scan a file with classes', () {
    final file = StringAsset('''
      class Shape {
       void draw() {}
       }
      class Rectangle extends Shape {}
      class Box<T> implements Shape {}
      class Boxes<List<T> with Shape {}
      abstract class AbstractShape {}
      final class FinalShape {}
      interface class Shape2 {}
      sealed class Shape3 {}
      base class Shape4 {}
      mixin class GenericMixin<T> {}
      class AliasedClass<T> = GenericClass<T> with GenericMixin<T>;
    ''');
    scanner.scan(file);
    final expected = [
      ['Shape', file.id, SymbolType.$class.value],
      ['Rectangle', file.id, SymbolType.$class.value],
      ['Box', file.id, SymbolType.$class.value],
      ['Boxes', file.id, SymbolType.$class.value],
      ['AbstractShape', file.id, SymbolType.$class.value],
      ['FinalShape', file.id, SymbolType.$class.value],
      ['Shape2', file.id, SymbolType.$class.value],
      ['Shape3', file.id, SymbolType.$class.value],
      ['Shape4', file.id, SymbolType.$class.value],
      ['GenericMixin', file.id, SymbolType.$class.value],
      ['AliasedClass', file.id, SymbolType.$class.value],
    ];
    expect(assetsGraph.identifiers, expected);
  });

  // functions
  test('TopLevelScanner should scan a file with functions', () {
    final file = StringAsset('''
    noReturn() {}
    void printMsg(String message) {}
    int add(int a, int b) => a + b;
    void configure({required String apiKey}) {}
    List<int> getRange(int start, [int end = 10]) => [];
    List<Set<T>> nestedList<T>(Mix<T> list) => [];
    T identity<T>(T value) => value;
    Future<String> fetchData() async => '';
    Stream<int> countStream(int max) async* {
      yield 1;
    }
    Future<void> runTests(List<String> args) async {}
    bool codeUnitForDigit(int digit) => digit < 10;
    Future<List<Map<String, dynamic>>> processSourceReport() async => [];
 ''');

    scanner.scan(file);
    final expected = [
      ['noReturn', file.id, SymbolType.$function.value],
      ['printMsg', file.id, SymbolType.$function.value],
      ['add', file.id, SymbolType.$function.value],
      ['configure', file.id, SymbolType.$function.value],
      ['getRange', file.id, SymbolType.$function.value],
      ['nestedList', file.id, SymbolType.$function.value],
      ['identity', file.id, SymbolType.$function.value],
      ['fetchData', file.id, SymbolType.$function.value],
      ['countStream', file.id, SymbolType.$function.value],
      ['runTests', file.id, SymbolType.$function.value],
      ['codeUnitForDigit', file.id, SymbolType.$function.value],
      ['processSourceReport', file.id, SymbolType.$function.value],
    ];
    expect(assetsGraph.identifiers, expected);
  });

  test('TopLevelScanner should scan advanced function syntax variants', () {
    final file = StringAsset('''
        Iterable<int> syncGenerator(int max) sync* {
          for (int i = 0; i < max; i++) {
            yield i;
          }
         }
        external void nativeFunction();
        Map<K, List<V>> groupBy<K, V>(List<V> items, K Function(V item) keySelector) => {};
        Future<List<Map<String, List<int>>>> processComplexData() async => [];
        int Function(int) makeAdder(int addBy) => (int a) => a + addBy;
        T operator <T>(T other) => other;
        int? nullableReturn() => null;
        void functionWithRecords((String, int) record) {}
        (String, int) returnRecord() => ('hello', 42);
        ({String name, int age}) namedRecord({String name = '', int age = 0}) => (name: name, age: age);
  ''');

    scanner.scan(file);
    final expected = [
      ['syncGenerator', file.id, SymbolType.$function.value],
      ['nativeFunction', file.id, SymbolType.$function.value],
      ['groupBy', file.id, SymbolType.$function.value],
      ['processComplexData', file.id, SymbolType.$function.value],
      ['makeAdder', file.id, SymbolType.$function.value],
      ['operator', file.id, SymbolType.$function.value],
      ['nullableReturn', file.id, SymbolType.$function.value],
      ['functionWithRecords', file.id, SymbolType.$function.value],
      ['returnRecord', file.id, SymbolType.$function.value],
      ['namedRecord', file.id, SymbolType.$function.value],
    ];
    expect(assetsGraph.identifiers, expected);
  });

  test('Should parse simple import', () {
    final src = StringAsset("import 'package:root/path.dart';");
    scanner.registerAndScan(src);
    final imports = assetsGraph.importsOf(src.id);
    expect(imports.length, 1);
    final importArr = imports.first;
    expect(importArr, [DirectiveStatement.import, src.id, 'package:root/path.dart', null, null]);
  });

  test('Should parse simple import with alias', () {
    final file = StringAsset("import 'package:root/path.dart' as i;");
    scanner.scan(file);
    final imports = assetsGraph.importsOf(file.id);
    expect(imports.length, 1);
    expect(imports.first, [DirectiveStatement.import, file.id, 'package:root/path.dart', null, null, 'i']);
  });

  test('Should parse simple deferred import', () {
    final file = StringAsset("import 'package:root/path.dart' deferred as i;", uriString: 'package:root/path.dart');
    scanner.scan(file);
    final imports = assetsGraph.importsOf(file.id);
    expect(imports.length, 1);
    expect(imports.first, [DirectiveStatement.import, file.id, 'package:root/path.dart', null, null, 'i', 1]);
  });

  test('Should parse simple import with show', () {
    final asset = StringAsset("import 'package:root/path.dart' show A, B;");
    scanner.registerAndScan(asset);
    final imports = assetsGraph.importsOf(asset.id);
    expect(imports.length, 1);
    expect(imports.first, [
      DirectiveStatement.import,
      asset.id,
      'package:root/path.dart',
      ['A', 'B'],
      null,
    ]);
  });

  test('Should parse simple import with hide', () {
    final asset = StringAsset("import 'package:root/path.dart' hide A, B;");
    scanner.registerAndScan(asset);
    final imports = assetsGraph.importsOf(asset.id);
    expect(imports.first, [
      DirectiveStatement.import,
      asset.id,
      'package:root/path.dart',
      null,
      ['A', 'B'],
    ]);
  });

  test('Should parse simple import with show and hide', () {
    final file = StringAsset("import 'package:root/path.dart' show A, B hide C, D;");
    scanner.scan(file);
    final imports = assetsGraph.importsOf(file.id);
    expect(imports.length, 1);
    expect(imports.first, [
      DirectiveStatement.import,
      file.id,
      'package:root/path.dart',
      ['A', 'B'],
      ['C', 'D'],
    ]);
  });

  test('Should parse simple export', () {
    final file = StringAsset("export 'package:root/path.dart';");
    scanner.scan(file);
    final exports = assetsGraph.exportsOf(file.id);
    expect(exports.first, [DirectiveStatement.export, file.id, 'package:root/path.dart', null, null]);
  });

  test('Should parse simple export with show', () {
    final file = StringAsset("export 'package:root/path.dart' show A, B;", uriString: 'package:root/path.dart');
    scanner.scan(file);
    final exports = assetsGraph.exportsOf(file.id);
    expect(exports.first, [
      DirectiveStatement.export,
      file.id,
      'package:root/path.dart',
      ['A', 'B'],
      null,
    ]);
  });

  test('Should parse simple export with hide', () {
    final file = StringAsset("export 'package:root/path.dart' hide A, B;", uriString: 'package:root/path.dart');
    scanner.scan(file);
    final exports = assetsGraph.exportsOf(file.id);
    expect(exports.first, [
      DirectiveStatement.export,
      file.id,
      'package:root/path.dart',
      null,
      ['A', 'B'],
    ]);
  });

  test('Should parse simple export with show and hide', () {
    final file = StringAsset(
      "export 'package:root/path.dart' show A, B hide C, D;",
      uriString: 'package:root/path.dart',
    );
    scanner.scan(file);
    final exports = assetsGraph.exportsOf(file.id);
    expect(exports.first, [
      DirectiveStatement.export,
      file.id,
      'package:root/path.dart',
      ['A', 'B'],
      ['C', 'D'],
    ]);
  });

  test('Should parse simple part', () {
    final file = StringAsset("part 'package:root/path.dart';");
    scanner.registerAndScan(file);
    final imports = assetsGraph.importsOf(file.id);
    final exports = assetsGraph.exportsOf(file.id);
    final parts = assetsGraph.partsOf(file.id);
    expect(imports.first, [DirectiveStatement.part, file.id, 'package:root/path.dart', null, null]);
    expect(exports.first, [DirectiveStatement.part, file.id, 'package:root/path.dart', null, null]);
    expect(parts.first, [DirectiveStatement.part, file.id, 'package:root/path.dart', null, null]);
  });

  test('Should parse part of', () {
    final asset = StringAsset("part of 'path.dart';", uriString: 'path.dart');
    scanner.registerAndScan(asset, relativeTo: asset);
    expect(assetsGraph.partOfOf(asset.id), isNotNull);
  });

  test('TopLevelScanner should detect class annotation', () {
    final asset = StringAsset('''
      @Annotation()
      class MyClass {}
    ''');
    scanner.registerAndScan(asset);
    expect(assetsGraph.identifiers.first, ['MyClass', asset.id, SymbolType.$class.value]);
    expect(assetsGraph.assets[asset.id]?[2], 1);
  });

  test('TopLevelScanner should detect class annotation with arguments', () {
    final file = StringAsset('''
      @Annotation('arg1', arg2: 42)
      class MyClass {}
    ''');
    scanner.scan(file);
    expect(assetsGraph.identifiers.first, ['MyClass', file.id, SymbolType.$class.value]);
    expect(assetsGraph.assets[file.id]?[2], 1);
  });

  test('TopLevelScanner should detect class annotation with constant var', () {
    final file = StringAsset('''
      @annotation
      class MyClass {}
    ''');
    scanner.scan(file);
    expect(assetsGraph.identifiers.first, ['MyClass', file.id, SymbolType.$class.value]);
    expect(assetsGraph.assets[file.id]?[2], 1);
  });

  test('TopLevelScanner should detect const var annotation', () {
    final file = StringAsset('''
      @Annotation()
      const myVar = 42;
    ''');
    scanner.scan(file);
    expect(assetsGraph.identifiers.first, ['myVar', file.id, SymbolType.$variable.value]);
    expect(assetsGraph.assets[file.id]?[2], 1);
  });

  test('TopLevelScanner should detect const var annotation', () {
    final file = StringAsset('''
      @Annotation.named()
      const myVar = 42;
    ''');
    scanner.scan(file);
    expect(assetsGraph.identifiers.first, ['myVar', file.id, SymbolType.$variable.value]);
    expect(assetsGraph.assets[file.id]?[2], 1);
  });

  test('TopLevelScanner should detect class annotated with import-prefixed annotation', () {
    final file = StringAsset('''
      @prefix.Annotation()
      @prefix.Annotation.named()
      class MyClass {}
    ''');
    scanner.scan(file);
    expect(assetsGraph.identifiers.first, ['MyClass', file.id, SymbolType.$class.value]);
    expect(assetsGraph.assets[file.id]?[2], 1);
  });

  test('TopLevelScanner should detect multiple annotations', () {
    final file = StringAsset('''
      @Annotation1()
      @Annotation2()
      class MyClass {}
    ''');
    scanner.scan(file);
    expect(assetsGraph.identifiers.first, ['MyClass', file.id, SymbolType.$class.value]);
    expect(assetsGraph.assets[file.id]?[2], 1);
  });

  // function annotation
  test('TopLevelScanner should detect function annotation', () {
    final file = StringAsset('''
      @Annotation()
      @Annotation.named()
      @annotation
      void myFunction() {}
    ''');
    scanner.scan(file);
    expect(assetsGraph.identifiers.first, ['myFunction', file.id, SymbolType.$function.value]);
    expect(assetsGraph.assets[file.id]?[2], 1);
  });

  test('TopLevelScanner should ignore field, method, any class member annotation', () {
    final file = StringAsset('''
      class MyClass {
        @Annotation()
        int myField = 42;
        @Annotation()
        void myMethod() {}
      }
    ''');
    scanner.scan(file);
    expect(assetsGraph.identifiers.first, ['MyClass', file.id, SymbolType.$class.value]);
    expect(assetsGraph.assets[file.id]?[2], 0);
  });

  test('TopLevelScanner should ignore top functions parameter annotation', () {
    final file = StringAsset('''
      void myFunction(@Annotation() int arg) {}
    ''');
    scanner.scan(file);
    expect(assetsGraph.identifiers.first, ['myFunction', file.id, SymbolType.$function.value]);
    expect(assetsGraph.assets[file.id]?[2], 0);
  });
}
