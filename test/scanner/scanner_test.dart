import 'package:lean_builder/src/scanner/assets_graph.dart';
import 'package:lean_builder/src/scanner/directive_statement.dart';
import 'package:lean_builder/src/scanner/scan_results.dart';
import 'package:lean_builder/src/scanner/top_level_scanner.dart';
import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';

import '../utils/mock_package_file_resolver.dart';
import 'string_asset_src.dart';

main() {
  late TopLevelScanner scanner;
  late AssetsGraph assetsGraph;
  setUp(() {
    final mockPackageFileResolver = MockPackageFileResolver();
    assetsGraph = AssetsGraph(mockPackageFileResolver.packagesHash);
    scanner = TopLevelScanner(assetsGraph, mockPackageFileResolver);
  });

  test('TopLevelScanner should scan a file with const variables', () {
    final file = StringSrc('''
    String stringVar = 'string';
    const int _privateConst = 42;
    final int finalInt = 42;
    const kPi = 3.14159;
    const inferredConst = 3.14159;
    const List<String> constants = ['A', 'B'];
    const Map<int, List<int>> kValue = _kValue; 
    ''');
    scanner.scanFile(file);
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
    final file = StringSrc('''
    // const kPi = 3.14159;
    // class Shape {}
    // void add(){}
    /* const constInt = 42; */
    ''');
    scanner.scanFile(file);
    expect(assetsGraph.identifiers.isEmpty, true);
  });

  // member variables/methods should be ignored
  test('TopLevelScanner should ignore member variables and methods', () {
    final file = StringSrc('''
    class MyClass {
      static const privateInt = 42;
      final int finalInt = 42;
      late final String lateString;
      void privateMethod() {}
      int get getter => 42;
      set setter(int value) {}
      abstract void abstractMethod();
    }
    ''');
    scanner.scanFile(file);
    expect(assetsGraph.identifiers.length, 1);
  });

  test('TopLevelScanner should scan a file with enums', () {
    final file = StringSrc('''
    enum Enum { red, green, blue }
    enum EnumWithImpl implements Logger { red, green, blue }
    ''');
    scanner.scanFile(file);
    final expected = [
      ['Enum', file.id, TopLevelIdentifierType.$enum.value],
      ['EnumWithImpl', file.id, TopLevelIdentifierType.$enum.value],
    ];
    expect(assetsGraph.identifiers, expected);
  });

  // typedef
  test('TopLevelScanner should scan a file with typedefs', () {
    final file = StringSrc('''
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
    scanner.scanFile(file);
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
    final file = StringSrc('''
    extension StringExt on String {}
    extension ListExt<S> on List<S> {}
    extension type const TypeExt(double? offset) {}
    extension type TypeExt2(double? offset) {}
    ''');
    scanner.scanFile(file);
    final expected = [
      ['StringExt', file.id, TopLevelIdentifierType.$extension.value],
      ['ListExt', file.id, TopLevelIdentifierType.$extension.value],
      ['TypeExt', file.id, TopLevelIdentifierType.$extension.value],
      ['TypeExt2', file.id, TopLevelIdentifierType.$extension.value],
    ];
    expect(assetsGraph.identifiers, expected);
  });

  test('TopLevelScanner should scan a file with mixins', () {
    final file = StringSrc('''
    mixin Logger {
      void log(String msg) {}
    }
    mixin Logger2 on Logger {
      void log2(String msg) {}
    }
    ''');
    scanner.scanFile(file);
    final expected = [
      ['Logger', file.id, TopLevelIdentifierType.$mixin.value],
      ['Logger2', file.id, TopLevelIdentifierType.$mixin.value],
    ];
    expect(assetsGraph.identifiers, expected);
  });

  test('TopLevelScanner should scan a file with classes', () {
    final file = StringSrc('''
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
    scanner.scanFile(file);
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
    final file = StringSrc('''
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

    scanner.scanFile(file);
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
    final file = StringSrc('''
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

    scanner.scanFile(file);
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
    final file = StringSrc("import 'path.dart';", uri: 'path.dart');
    scanner.scanFile(file);
    final imports = assetsGraph.importsOf(file.id);
    expect(imports.length, 1);
    final importArr = imports.first;
    expect(importArr, [DirectiveStatement.import, file.id, 'path.dart', null, null]);
  });

  test('Should parse simple import with alias', () {
    final file = StringSrc("import 'path.dart' as i;", uri: 'path.dart');
    scanner.scanFile(file);
    final imports = assetsGraph.importsOf(file.id);
    expect(imports.length, 1);
    expect(imports.first, [DirectiveStatement.import, file.id, 'path.dart', null, null, 'i']);
  });

  test('Should parse simple deferred import', () {
    final file = StringSrc("import 'path.dart' deferred as i;", uri: 'path.dart');
    scanner.scanFile(file);
    final imports = assetsGraph.importsOf(file.id);
    expect(imports.length, 1);
    expect(imports.first, [DirectiveStatement.import, file.id, 'path.dart', null, null, 'i', 1]);
  });

  test('Should parse simple import with show', () {
    final file = StringSrc("import 'path.dart' show A, B;", uri: 'path.dart');
    scanner.scanFile(file);
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
    final file = StringSrc("import 'path.dart' hide A, B;", uri: 'path.dart');
    scanner.scanFile(file);
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
    final file = StringSrc("import 'path.dart' show A, B hide C, D;", uri: 'path.dart');
    scanner.scanFile(file);
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
    final file = StringSrc("export 'path.dart';", uri: 'path.dart');
    scanner.scanFile(file);
    final exports = assetsGraph.exportsOf(file.id);
    expect(exports.first, [DirectiveStatement.export, file.id, 'path.dart', null, null]);
  });

  test('Should parse simple export with show', () {
    final file = StringSrc("export 'path.dart' show A, B;", uri: 'path.dart');
    scanner.scanFile(file);
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
    final file = StringSrc("export 'path.dart' hide A, B;", uri: 'path.dart');
    scanner.scanFile(file);
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
    final file = StringSrc("export 'path.dart' show A, B hide C, D;", uri: 'path.dart');
    scanner.scanFile(file);
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
    final file = StringSrc("part 'path.dart';", uri: 'path.dart');
    scanner.scanFile(file);
    final imports = assetsGraph.importsOf(file.id);
    final exports = assetsGraph.exportsOf(file.id);
    final parts = assetsGraph.partsOf(file.id);
    expect(imports.first, [DirectiveStatement.part, file.id, 'path.dart', null, null]);
    expect(exports.first, [DirectiveStatement.part, file.id, 'path.dart', null, null]);
    expect(parts.first, [DirectiveStatement.part, file.id, 'path.dart', null, null]);
  });

  test('Should parse part of', () {
    final file = StringSrc("part of 'path.dart';");
    scanner.scanFile(file);
    expect(assetsGraph.partOfOf(file.id), isNotNull);
  });

  test('TopLevelScanner should detect class annotation', () {
    final file = StringSrc('''
      @Annotation()
      class MyClass {}
    ''');
    scanner.scanFile(file);
    expect(assetsGraph.identifiers.first, ['MyClass', file.id, TopLevelIdentifierType.$class.value]);
    expect(assetsGraph.assets[file.id]?[2], 1);
  });

  test('TopLevelScanner should detect class annotation with arguments', () {
    final file = StringSrc('''
      @Annotation('arg1', arg2: 42)
      class MyClass {}
    ''');
    scanner.scanFile(file);
    expect(assetsGraph.identifiers.first, ['MyClass', file.id, TopLevelIdentifierType.$class.value]);
    expect(assetsGraph.assets[file.id]?[2], 1);
  });

  test('TopLevelScanner should detect class annotation with const var', () {
    final file = StringSrc('''
      @annotation
      class MyClass {}
    ''');
    scanner.scanFile(file);
    expect(assetsGraph.identifiers.first, ['MyClass', file.id, TopLevelIdentifierType.$class.value]);
    expect(assetsGraph.assets[file.id]?[2], 1);
  });

  test('TopLevelScanner should detect const var annotation', () {
    final file = StringSrc('''
      @Annotation()
      const myVar = 42;
    ''');
    scanner.scanFile(file);
    expect(assetsGraph.identifiers.first, ['myVar', file.id, TopLevelIdentifierType.$variable.value]);
    expect(assetsGraph.assets[file.id]?[2], 1);
  });

  test('TopLevelScanner should detect const var annotation', () {
    final file = StringSrc('''
      @Annotation.named()
      const myVar = 42;
    ''');
    scanner.scanFile(file);
    expect(assetsGraph.identifiers.first, ['myVar', file.id, TopLevelIdentifierType.$variable.value]);
    expect(assetsGraph.assets[file.id]?[2], 1);
  });

  test('TopLevelScanner should detect class annotated with import-prefixed annotation', () {
    final file = StringSrc('''
      @prefix.Annotation()
      @prefix.Annotation.named()
      class MyClass {}
    ''');
    scanner.scanFile(file);
    expect(assetsGraph.identifiers.first, ['MyClass', file.id, TopLevelIdentifierType.$class.value]);
    expect(assetsGraph.assets[file.id]?[2], 1);
  });

  test('TopLevelScanner should detect multiple annotations', () {
    final file = StringSrc('''
      @Annotation1()
      @Annotation2()
      class MyClass {}
    ''');
    scanner.scanFile(file);
    expect(assetsGraph.identifiers.first, ['MyClass', file.id, TopLevelIdentifierType.$class.value]);
    expect(assetsGraph.assets[file.id]?[2], 1);
  });

  // function annotation
  test('TopLevelScanner should detect function annotation', () {
    final file = StringSrc('''
      @Annotation()
      @Annotation.named()
      @annotation
      void myFunction() {}
    ''');
    scanner.scanFile(file);
    expect(assetsGraph.identifiers.first, ['myFunction', file.id, TopLevelIdentifierType.$function.value]);
    expect(assetsGraph.assets[file.id]?[2], 1);
  });

  test('TopLevelScanner should ignore field, method, any class member annotation', () {
    final file = StringSrc('''
      class MyClass {
        @Annotation()
        int myField = 42;
        @Annotation()
        void myMethod() {}
      }
    ''');
    scanner.scanFile(file);
    expect(assetsGraph.identifiers.first, ['MyClass', file.id, TopLevelIdentifierType.$class.value]);
    expect(assetsGraph.assets[file.id]?[2], 0);
  });

  test('TopLevelScanner should ignore top functions parameter annotation', () {
    final file = StringSrc('''
      void myFunction(@Annotation() int arg) {}
    ''');
    scanner.scanFile(file);
    expect(assetsGraph.identifiers.first, ['myFunction', file.id, TopLevelIdentifierType.$function.value]);
    expect(assetsGraph.assets[file.id]?[2], 0);
  });
}
