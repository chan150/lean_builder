import 'package:code_genie/src/scanner/assets_graph.dart';
import 'package:code_genie/src/scanner/scan_results.dart';
import 'package:code_genie/src/scanner/top_level_scanner.dart';
import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';

import '../utils/mock_package_file_resolver.dart';
import 'asset_file_mock.dart';

main() {
  late TopLevelScanner scanner;
  late AssetsGraph assetsGraph;
  setUp(() {
    final mockPackageFileResolver = MockPackageFileResolver();
    assetsGraph = AssetsGraph(mockPackageFileResolver.packagesHash);
    scanner = TopLevelScanner(assetsGraph, mockPackageFileResolver);
  });

  test('TopLevelScanner should scan a file with const variables', () {
    final file = AssetFileMock('''
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
      ['kPi', file.id, IdentifierType.$variable.value],
      ['inferredConst', file.id, IdentifierType.$variable.value],
      ['constants', file.id, IdentifierType.$variable.value],
      ['kValue', file.id, IdentifierType.$variable.value],
    ];
    expect(assetsGraph.identifiers, expected);
  });

  test('TopLevelScanner should ignore commented out identifiers', () {
    final file = AssetFileMock('''
    // const kPi = 3.14159;
    // class Shape {}
    // void add(){}
    /* const constInt = 42; */
    ''');
    scanner.scanFile(file);
    expect(assetsGraph.identifiers.isEmpty, true);
  });

  test('TopLevelScanner should scan a file with enums', () {
    final file = AssetFileMock('''
    enum Enum { red, green, blue }
    enum EnumWithImpl implements Logger { red, green, blue }
    ''');
    scanner.scanFile(file);
    final expected = [
      ['Enum', file.id, IdentifierType.$enum.value],
      ['EnumWithImpl', file.id, IdentifierType.$enum.value],
    ];
    expect(assetsGraph.identifiers, expected);
  });

  // typedef
  test('TopLevelScanner should scan a file with typedefs', () {
    final file = AssetFileMock('''
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
      ['JsonMap', file.id, IdentifierType.$typeAlias.value],
      ['Record', file.id, IdentifierType.$typeAlias.value],
      ['Callback', file.id, IdentifierType.$typeAlias.value],
      ['GenericCallback', file.id, IdentifierType.$typeAlias.value],
      ['GenericCallback2', file.id, IdentifierType.$typeAlias.value],
      ['ElementPredicate', file.id, IdentifierType.$typeAlias.value],
      ['TypeName', file.id, IdentifierType.$typeAlias.value],
      ['ConsumerCallback', file.id, IdentifierType.$typeAlias.value],
      ['NullableMap', file.id, IdentifierType.$typeAlias.value],
      ['FunctionFactory', file.id, IdentifierType.$typeAlias.value],
      ['Comparable', file.id, IdentifierType.$typeAlias.value],
      ['ComplexRecord', file.id, IdentifierType.$typeAlias.value],
      ['KeyValuePair', file.id, IdentifierType.$typeAlias.value],
      ['OptionalParams', file.id, IdentifierType.$typeAlias.value],
      ['NamedParams', file.id, IdentifierType.$typeAlias.value],
      ['JsonProcessor', file.id, IdentifierType.$typeAlias.value],
      ['Transformer', file.id, IdentifierType.$typeAlias.value],
    ];
    expect(assetsGraph.identifiers, expected);
  });

  test('TopLevelScanner should scan a file with extensions', () {
    final file = AssetFileMock('''
    extension StringExt on String {
      String capitalize() => this;
    }
    extension IntExt on int {
      int double() => this * 2;
    }
    ''');
    scanner.scanFile(file);
    final expected = [
      ['StringExt', file.id, IdentifierType.$extension.value],
      ['IntExt', file.id, IdentifierType.$extension.value],
    ];
    expect(assetsGraph.identifiers, expected);
  });

  test('TopLevelScanner should scan a file with mixins', () {
    final file = AssetFileMock('''
    mixin Logger {
      void log(String msg) {}
    }
    mixin Logger2 on Logger {
      void log2(String msg) {}
    }
    ''');
    scanner.scanFile(file);
    final expected = [
      ['Logger', file.id, IdentifierType.$mixin.value],
      ['Logger2', file.id, IdentifierType.$mixin.value],
    ];
    expect(assetsGraph.identifiers, expected);
  });

  test('TopLevelScanner should scan a file with classes', () {
    final file = AssetFileMock('''
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
    ''');
    scanner.scanFile(file);
    final expected = [
      ['Shape', file.id, IdentifierType.$class.value],
      ['Rectangle', file.id, IdentifierType.$class.value],
      ['Box', file.id, IdentifierType.$class.value],
      ['Boxes', file.id, IdentifierType.$class.value],
      ['AbstractShape', file.id, IdentifierType.$class.value],
      ['FinalShape', file.id, IdentifierType.$class.value],
      ['Shape2', file.id, IdentifierType.$class.value],
      ['Shape3', file.id, IdentifierType.$class.value],
      ['Shape4', file.id, IdentifierType.$class.value],
    ];
    expect(assetsGraph.identifiers, expected);
  });

  // functions
  test('TopLevelScanner should scan a file with functions', () {
    final file = AssetFileMock('''
    void printMsg(String message) {}
    int add(int a, int b) => a + b;
    void configure({required String apiKey}) {}
    List<int> getRange(int start, [int end = 10]) => [];
    List<List<T>> nestedList<T>(List<T> list) => [];
    noReturn() {}
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
      ['printMsg', file.id, IdentifierType.$function.value],
      ['add', file.id, IdentifierType.$function.value],
      ['configure', file.id, IdentifierType.$function.value],
      ['getRange', file.id, IdentifierType.$function.value],
      ['nestedList', file.id, IdentifierType.$function.value],
      ['noReturn', file.id, IdentifierType.$function.value],
      ['identity', file.id, IdentifierType.$function.value],
      ['fetchData', file.id, IdentifierType.$function.value],
      ['countStream', file.id, IdentifierType.$function.value],
      ['runTests', file.id, IdentifierType.$function.value],
      ['codeUnitForDigit', file.id, IdentifierType.$function.value],
      ['processSourceReport', file.id, IdentifierType.$function.value],
    ];
    expect(assetsGraph.identifiers, expected);
  });

  // should parse simple import (import 'path.dart');
  test('Should parse simple import', () {
    final file = AssetFileMock("import 'path.dart';");
    scanner.scanFile(file);
    expect(assetsGraph.imports.length, 1);
    final importArr = assetsGraph.imports.values.first;
    expect(importArr.length, 1);
    expect(importArr.first, [file.id]);
  });

  test('Should parse simple import with alias', () {
    final file = AssetFileMock("import 'path.dart' as i;");
    scanner.scanFile(file);
    expect(assetsGraph.imports.length, 1);
    final importArr = assetsGraph.imports.values.first;
    expect(importArr.length, 1);
    expect(importArr.first, [file.id]);
  });

  test('Should parse simple import with show', () {
    final file = AssetFileMock("import 'path.dart' show A, B;");
    scanner.scanFile(file);
    expect(assetsGraph.imports.length, 1);
    final importArr = assetsGraph.imports.values.first;
    expect(importArr.first, [
      file.id,
      ['A', 'B'],
    ]);
  });

  test('Should parse simple import with hide', () {
    final file = AssetFileMock("import 'path.dart' hide A, B;");
    scanner.scanFile(file);
    expect(assetsGraph.imports.length, 1);
    final importArr = assetsGraph.imports.values.first;
    expect(importArr.first, [
      file.id,
      [],
      ['A', 'B'],
    ]);
  });

  test('Should parse simple import with show and hide', () {
    final file = AssetFileMock("import 'path.dart' show A, B hide C, D;");
    scanner.scanFile(file);
    expect(assetsGraph.imports.length, 1);
    final importArr = assetsGraph.imports.values.first;
    expect(importArr.first, [
      file.id,
      ['A', 'B'],
      ['C', 'D'],
    ]);
  });

  test('Should parse simple export', () {
    final file = AssetFileMock("export 'path.dart';");
    scanner.scanFile(file);
    expect(assetsGraph.exports.length, 1);
    final exportArr = assetsGraph.exports.values.first;
    expect(exportArr.length, 1);
    expect(exportArr.first, [file.id]);
  });

  test('Should parse simple export with show', () {
    final file = AssetFileMock("export 'path.dart' show A, B;");
    scanner.scanFile(file);
    expect(assetsGraph.exports.length, 1);
    final exportArr = assetsGraph.exports.values.first;
    expect(exportArr.first, [
      file.id,
      ['A', 'B'],
    ]);
  });

  test('Should parse simple export with hide', () {
    final file = AssetFileMock("export 'path.dart' hide A, B;");
    scanner.scanFile(file);
    expect(assetsGraph.exports.length, 1);
    final exportArr = assetsGraph.exports.values.first;
    expect(exportArr.first, [
      file.id,
      [],
      ['A', 'B'],
    ]);
  });

  test('Should parse simple export with show and hide', () {
    final file = AssetFileMock("export 'path.dart' show A, B hide C, D;");
    scanner.scanFile(file);
    expect(assetsGraph.exports.length, 1);
    final exportArr = assetsGraph.exports.values.first;
    expect(exportArr.first, [
      file.id,
      ['A', 'B'],
      ['C', 'D'],
    ]);
  });

  test('Should parse simple part', () {
    final file = AssetFileMock("part 'path.dart';");
    scanner.scanFile(file);
    expect(assetsGraph.imports.length, 1);
    expect(assetsGraph.exports.length, 1);
    expect(assetsGraph.imports.values.first.first, [file.id]);
    expect(assetsGraph.exports.values.first.first, [file.id]);
  });

  test('Should ignore part of', () {
    final file = AssetFileMock("part of 'path.dart';");
    scanner.scanFile(file);
    expect(assetsGraph.imports.isEmpty, true);
    expect(assetsGraph.exports.isEmpty, true);
  });

  test('TopLevelScanner should detect class annotation', () {
    final file = AssetFileMock('''
      @Annotation()
      class MyClass {}
    ''');
    scanner.scanFile(file);
    expect(assetsGraph.identifiers.first, ['MyClass', file.id, IdentifierType.$class.value]);
    expect(assetsGraph.assets[file.id]?[2], 1);
  });

  test('TopLevelScanner should detect class annotation with arguments', () {
    final file = AssetFileMock('''
      @Annotation('arg1', arg2: 42)
      class MyClass {}
    ''');
    scanner.scanFile(file);
    expect(assetsGraph.identifiers.first, ['MyClass', file.id, IdentifierType.$class.value]);
    expect(assetsGraph.assets[file.id]?[2], 1);
  });

  test('TopLevelScanner should detect class annotation with const var', () {
    final file = AssetFileMock('''
      @annotation
      class MyClass {}
    ''');
    scanner.scanFile(file);
    expect(assetsGraph.identifiers.first, ['MyClass', file.id, IdentifierType.$class.value]);
    expect(assetsGraph.assets[file.id]?[2], 1);
  });

  test('TopLevelScanner should detect const var annotation', () {
    final file = AssetFileMock('''
      @Annotation()
      const myVar = 42;
    ''');
    scanner.scanFile(file);
    expect(assetsGraph.identifiers.first, ['myVar', file.id, IdentifierType.$variable.value]);
    expect(assetsGraph.assets[file.id]?[2], 1);
  });

  test('TopLevelScanner should detect multiple annotations', () {
    final file = AssetFileMock('''
      @Annotation1()
      @Annotation2()
      class MyClass {}
    ''');
    scanner.scanFile(file);
    expect(assetsGraph.identifiers.first, ['MyClass', file.id, IdentifierType.$class.value]);
    expect(assetsGraph.assets[file.id]?[2], 1);
  });

  // function annotation
  test('TopLevelScanner should detect function annotation', () {
    final file = AssetFileMock('''
      @Annotation()
      void myFunction() {}
    ''');
    scanner.scanFile(file);
    expect(assetsGraph.identifiers.first, ['myFunction', file.id, IdentifierType.$function.value]);
    expect(assetsGraph.assets[file.id]?[2], 1);
  });

  test('TopLevelScanner should ignore field, method, any class member annotation', () {
    final file = AssetFileMock('''
      class MyClass {
        @Annotation()
        int myField = 42;
        @Annotation()
        void myMethod() {}
      }
    ''');
    scanner.scanFile(file);
    expect(assetsGraph.identifiers.first, ['MyClass', file.id, IdentifierType.$class.value]);
    expect(assetsGraph.assets[file.id]?[2], 0);
  });

  test('TopLevelScanner should ignore top functions parameter annotation', () {
    final file = AssetFileMock('''
      void myFunction(@Annotation() int arg) {}
    ''');
    scanner.scanFile(file);
    expect(assetsGraph.identifiers.first, ['myFunction', file.id, IdentifierType.$function.value]);
    expect(assetsGraph.assets[file.id]?[2], 0);
  });
}
