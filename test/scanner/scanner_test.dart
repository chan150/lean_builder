import 'package:lean_builder/src/asset/package_file_resolver.dart' show PackageFileResolverImpl;
import 'package:lean_builder/src/graph/assets_graph.dart' show AssetsGraph;
import 'package:lean_builder/src/graph/directive_statement.dart';
import 'package:lean_builder/src/graph/scan_results.dart';
import 'package:lean_builder/src/graph/symbols_scanner.dart' show AssetsScanner;

import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';

import 'string_asset_src.dart';

main() {
  late AssetsScanner scanner;
  late AssetsGraph assetsGraph;
  setUp(() {
    final fileResolver = PackageFileResolverImpl({'test': 'path/to/test'}, packagesHash: '', rootPackage: 'root');
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
      ['_privateConst', file.id, TopLevelIdentifierType.$variable.value],
      ['kPi', file.id, TopLevelIdentifierType.$variable.value],
      ['inferredConst', file.id, TopLevelIdentifierType.$variable.value],
      ['constants', file.id, TopLevelIdentifierType.$variable.value],
      ['kValue', file.id, TopLevelIdentifierType.$variable.value],
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
      ['Enum', file.id, TopLevelIdentifierType.$enum.value],
      ['EnumWithImpl', file.id, TopLevelIdentifierType.$enum.value],
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
      ['JsonMap', file.id, TopLevelIdentifierType.$typeAlias.value],
      ['Record', file.id, TopLevelIdentifierType.$typeAlias.value],
      ['Callback', file.id, TopLevelIdentifierType.$typeAlias.value],
      ['GenericCallback', file.id, TopLevelIdentifierType.$typeAlias.value],
      ['GenericCallback2', file.id, TopLevelIdentifierType.$typeAlias.value],
      ['ElementPredicate', file.id, TopLevelIdentifierType.$typeAlias.value],
      ['TypeName', file.id, TopLevelIdentifierType.$typeAlias.value],
      ['ConsumerCallback', file.id, TopLevelIdentifierType.$typeAlias.value],
      ['NullableMap', file.id, TopLevelIdentifierType.$typeAlias.value],
      ['FunctionFactory', file.id, TopLevelIdentifierType.$typeAlias.value],
      ['Comparable', file.id, TopLevelIdentifierType.$typeAlias.value],
      ['ComplexRecord', file.id, TopLevelIdentifierType.$typeAlias.value],
      ['KeyValuePair', file.id, TopLevelIdentifierType.$typeAlias.value],
      ['OptionalParams', file.id, TopLevelIdentifierType.$typeAlias.value],
      ['NamedParams', file.id, TopLevelIdentifierType.$typeAlias.value],
      ['JsonProcessor', file.id, TopLevelIdentifierType.$typeAlias.value],
      ['Transformer', file.id, TopLevelIdentifierType.$typeAlias.value],
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
      ['StringExt', file.id, TopLevelIdentifierType.$extension.value],
      ['ListExt', file.id, TopLevelIdentifierType.$extension.value],
      ['TypeExt', file.id, TopLevelIdentifierType.$extension.value],
      ['TypeExt2', file.id, TopLevelIdentifierType.$extension.value],
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
      ['Logger', file.id, TopLevelIdentifierType.$mixin.value],
      ['Logger2', file.id, TopLevelIdentifierType.$mixin.value],
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
      ['Shape', file.id, TopLevelIdentifierType.$class.value],
      ['Rectangle', file.id, TopLevelIdentifierType.$class.value],
      ['Box', file.id, TopLevelIdentifierType.$class.value],
      ['Boxes', file.id, TopLevelIdentifierType.$class.value],
      ['AbstractShape', file.id, TopLevelIdentifierType.$class.value],
      ['FinalShape', file.id, TopLevelIdentifierType.$class.value],
      ['Shape2', file.id, TopLevelIdentifierType.$class.value],
      ['Shape3', file.id, TopLevelIdentifierType.$class.value],
      ['Shape4', file.id, TopLevelIdentifierType.$class.value],
      ['GenericMixin', file.id, TopLevelIdentifierType.$class.value],
      ['AliasedClass', file.id, TopLevelIdentifierType.$class.value],
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
      ['noReturn', file.id, TopLevelIdentifierType.$function.value],
      ['printMsg', file.id, TopLevelIdentifierType.$function.value],
      ['add', file.id, TopLevelIdentifierType.$function.value],
      ['configure', file.id, TopLevelIdentifierType.$function.value],
      ['getRange', file.id, TopLevelIdentifierType.$function.value],
      ['nestedList', file.id, TopLevelIdentifierType.$function.value],
      ['identity', file.id, TopLevelIdentifierType.$function.value],
      ['fetchData', file.id, TopLevelIdentifierType.$function.value],
      ['countStream', file.id, TopLevelIdentifierType.$function.value],
      ['runTests', file.id, TopLevelIdentifierType.$function.value],
      ['codeUnitForDigit', file.id, TopLevelIdentifierType.$function.value],
      ['processSourceReport', file.id, TopLevelIdentifierType.$function.value],
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
      ['syncGenerator', file.id, TopLevelIdentifierType.$function.value],
      ['nativeFunction', file.id, TopLevelIdentifierType.$function.value],
      ['groupBy', file.id, TopLevelIdentifierType.$function.value],
      ['processComplexData', file.id, TopLevelIdentifierType.$function.value],
      ['makeAdder', file.id, TopLevelIdentifierType.$function.value],
      ['operator', file.id, TopLevelIdentifierType.$function.value],
      ['nullableReturn', file.id, TopLevelIdentifierType.$function.value],
      ['functionWithRecords', file.id, TopLevelIdentifierType.$function.value],
      ['returnRecord', file.id, TopLevelIdentifierType.$function.value],
      ['namedRecord', file.id, TopLevelIdentifierType.$function.value],
    ];
    expect(assetsGraph.identifiers, expected);
  });

  test('Should parse simple import', () {
    final src = StringAsset("import 'path.dart';", uriString: 'path.dart');
    scanner.scan(src);
    final imports = assetsGraph.importsOf(src.id);
    expect(imports.length, 1);
    final importArr = imports.first;
    expect(importArr, [DirectiveStatement.import, src.id, 'path.dart', null, null]);
  });

  test('Should parse simple import with alias', () {
    final file = StringAsset("import 'path.dart' as i;", uriString: 'path.dart');
    scanner.scan(file);
    final imports = assetsGraph.importsOf(file.id);
    expect(imports.length, 1);
    expect(imports.first, [DirectiveStatement.import, file.id, 'path.dart', null, null, 'i']);
  });

  test('Should parse simple deferred import', () {
    final file = StringAsset("import 'path.dart' deferred as i;", uriString: 'path.dart');
    scanner.scan(file);
    final imports = assetsGraph.importsOf(file.id);
    expect(imports.length, 1);
    expect(imports.first, [DirectiveStatement.import, file.id, 'path.dart', null, null, 'i', 1]);
  });

  test('Should parse simple import with show', () {
    final file = StringAsset("import 'path.dart' show A, B;", uriString: 'path.dart');
    scanner.scan(file);
    final imports = assetsGraph.importsOf(file.id);
    expect(imports.length, 1);
    expect(imports.first, [
      DirectiveStatement.import,
      file.id,
      'path.dart',
      ['A', 'B'],
      null,
    ]);
  });

  test('Should parse simple import with hide', () {
    final file = StringAsset("import 'path.dart' hide A, B;", uriString: 'path.dart');
    scanner.scan(file);
    final imports = assetsGraph.importsOf(file.id);
    expect(imports.first, [
      DirectiveStatement.import,
      file.id,
      'path.dart',
      null,
      ['A', 'B'],
    ]);
  });

  test('Should parse simple import with show and hide', () {
    final file = StringAsset("import 'path.dart' show A, B hide C, D;", uriString: 'path.dart');
    scanner.scan(file);
    final imports = assetsGraph.importsOf(file.id);
    expect(imports.length, 1);
    expect(imports.first, [
      DirectiveStatement.import,
      file.id,
      'path.dart',
      ['A', 'B'],
      ['C', 'D'],
    ]);
  });

  test('Should parse simple export', () {
    final file = StringAsset("export 'path.dart';", uriString: 'path.dart');
    scanner.scan(file);
    final exports = assetsGraph.exportsOf(file.id);
    expect(exports.first, [DirectiveStatement.export, file.id, 'path.dart', null, null]);
  });

  test('Should parse simple export with show', () {
    final file = StringAsset("export 'path.dart' show A, B;", uriString: 'path.dart');
    scanner.scan(file);
    final exports = assetsGraph.exportsOf(file.id);
    expect(exports.first, [
      DirectiveStatement.export,
      file.id,
      'path.dart',
      ['A', 'B'],
      null,
    ]);
  });

  test('Should parse simple export with hide', () {
    final file = StringAsset("export 'path.dart' hide A, B;", uriString: 'path.dart');
    scanner.scan(file);
    final exports = assetsGraph.exportsOf(file.id);
    expect(exports.first, [
      DirectiveStatement.export,
      file.id,
      'path.dart',
      null,
      ['A', 'B'],
    ]);
  });

  test('Should parse simple export with show and hide', () {
    final file = StringAsset("export 'path.dart' show A, B hide C, D;", uriString: 'path.dart');
    scanner.scan(file);
    final exports = assetsGraph.exportsOf(file.id);
    expect(exports.first, [
      DirectiveStatement.export,
      file.id,
      'path.dart',
      ['A', 'B'],
      ['C', 'D'],
    ]);
  });

  test('Should parse simple part', () {
    final file = StringAsset("part 'path.dart';", uriString: 'path.dart');
    scanner.scan(file);
    final imports = assetsGraph.importsOf(file.id);
    final exports = assetsGraph.exportsOf(file.id);
    final parts = assetsGraph.partsOf(file.id);
    expect(imports.first, [DirectiveStatement.part, file.id, 'path.dart', null, null]);
    expect(exports.first, [DirectiveStatement.part, file.id, 'path.dart', null, null]);
    expect(parts.first, [DirectiveStatement.part, file.id, 'path.dart', null, null]);
  });

  test('Should parse part of', () {
    final file = StringAsset("part of 'path.dart';");
    scanner.scan(file);
    expect(assetsGraph.partOfOf(file.id), isNotNull);
  });

  test('TopLevelScanner should detect class annotation', () {
    final file = StringAsset('''
      @Annotation()
      class MyClass {}
    ''');
    scanner.scan(file);
    expect(assetsGraph.identifiers.first, ['MyClass', file.id, TopLevelIdentifierType.$class.value]);
    expect(assetsGraph.assets[file.id]?[2], 1);
  });

  test('TopLevelScanner should detect class annotation with arguments', () {
    final file = StringAsset('''
      @Annotation('arg1', arg2: 42)
      class MyClass {}
    ''');
    scanner.scan(file);
    expect(assetsGraph.identifiers.first, ['MyClass', file.id, TopLevelIdentifierType.$class.value]);
    expect(assetsGraph.assets[file.id]?[2], 1);
  });

  test('TopLevelScanner should detect class annotation with constant var', () {
    final file = StringAsset('''
      @annotation
      class MyClass {}
    ''');
    scanner.scan(file);
    expect(assetsGraph.identifiers.first, ['MyClass', file.id, TopLevelIdentifierType.$class.value]);
    expect(assetsGraph.assets[file.id]?[2], 1);
  });

  test('TopLevelScanner should detect const var annotation', () {
    final file = StringAsset('''
      @Annotation()
      const myVar = 42;
    ''');
    scanner.scan(file);
    expect(assetsGraph.identifiers.first, ['myVar', file.id, TopLevelIdentifierType.$variable.value]);
    expect(assetsGraph.assets[file.id]?[2], 1);
  });

  test('TopLevelScanner should detect const var annotation', () {
    final file = StringAsset('''
      @Annotation.named()
      const myVar = 42;
    ''');
    scanner.scan(file);
    expect(assetsGraph.identifiers.first, ['myVar', file.id, TopLevelIdentifierType.$variable.value]);
    expect(assetsGraph.assets[file.id]?[2], 1);
  });

  test('TopLevelScanner should detect class annotated with import-prefixed annotation', () {
    final file = StringAsset('''
      @prefix.Annotation()
      @prefix.Annotation.named()
      class MyClass {}
    ''');
    scanner.scan(file);
    expect(assetsGraph.identifiers.first, ['MyClass', file.id, TopLevelIdentifierType.$class.value]);
    expect(assetsGraph.assets[file.id]?[2], 1);
  });

  test('TopLevelScanner should detect multiple annotations', () {
    final file = StringAsset('''
      @Annotation1()
      @Annotation2()
      class MyClass {}
    ''');
    scanner.scan(file);
    expect(assetsGraph.identifiers.first, ['MyClass', file.id, TopLevelIdentifierType.$class.value]);
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
    expect(assetsGraph.identifiers.first, ['myFunction', file.id, TopLevelIdentifierType.$function.value]);
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
    expect(assetsGraph.identifiers.first, ['MyClass', file.id, TopLevelIdentifierType.$class.value]);
    expect(assetsGraph.assets[file.id]?[2], 0);
  });

  test('TopLevelScanner should ignore top functions parameter annotation', () {
    final file = StringAsset('''
      void myFunction(@Annotation() int arg) {}
    ''');
    scanner.scan(file);
    expect(assetsGraph.identifiers.first, ['myFunction', file.id, TopLevelIdentifierType.$function.value]);
    expect(assetsGraph.assets[file.id]?[2], 0);
  });
}
