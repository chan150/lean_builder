import 'package:lean_builder/test/test2.dart' as test2;
import 'package:lean_builder/test/test2.dart';
import 'package:meta/meta.dart';

typedef TypedType = void Function(int x, bool y);

abstract base class X {}

class Genix$ {
  final ObjectArg objectArg;
  final String? str2;

  const Genix$(this.objectArg) : str2 = 'str2';

  const Genix$.named(this.objectArg) : str2 = null;

  static const test2.SuperX named2 = test2.SuperX(superStr: 'SuperStr2');
}

const genix$ = Genix$(ObjectArg('Arg'));
const genixNamed = Genix$.named(ObjectArg('Arg'));
const String constArg = 'Hello';

class ObjectArg {
  const ObjectArg(this.arg);

  final String arg;
}

const constVar = 'Hello';

@immutable
// @internal
// @factory
// @Deprecated('This is deprecated')
// @deprecated
@alwaysThrows
// @visibleForOverriding
// @UseResult('Just because')
// @useResult
@sealed
// @reopen
// @redeclare
// @nonVirtual
// @isTestGroup
// @isTest
// @protected
// @literal
// @optionalTypeArgs
// @constVar
// @override
// @mustBeConst
// @mustBeOverridden
// @mustCallSuper
@doNotStore
enum ColorEnumWithArgs {
  red(constVar),
  green('green'),
  blue.named('blue', 200);

  final String value;

  final int shade;

  const ColorEnumWithArgs(this.value, [this.shade = 100]);

  const ColorEnumWithArgs.named(this.value, this.shade);

  void method() {
    print('Hello');
  }

  bool get isRed => value == 'red';
}

// @test2.SuperX()
// @genix$
// @Genix$(String, superStr: 'SuperStr2')
// @Genix$.named(String)
class AnnotatedClass {
  const AnnotatedClass(this.fieldType);

  final test2.FieldType fieldType;

  // final Target target;
  // final Future futre;
  // List<Set<String>> list = [];
  // // final FieldType type = FieldType('Hello', 1);
  //
  // // final List<String> list = ['one', 'two', 'three'];
  // final int intx = 1;
  // final bool boolx = true;
  // final String stringx = 'Hello';
  // final Future futurex = Future.value('Hello');
  // final List<String> listx = ['one', 'two', 'three'];
  // final Set<String> setx = {'one', 'two', 'three'};
  // final Iterable<String> iterablex = ['one', 'two', 'three'];
  // final Map<String, String> mapx = {'one': 'one', 'two': 'two', 'three': 'three'};

  // final ColorEnum color = ColorEnum.red;
  // void x;
  // dynamic dynamicField;

  // // AnnotatedClass(this.type, this.name, this.age, this.isAlive);
  //
  void method([String x = 'default']) {}

  void method2([String x = 'default']) {}

  factory AnnotatedClass.redirected() = RedirectedClass;
  factory AnnotatedClass.redirected2() = RedirectedClass.red;
  factory AnnotatedClass.redirected3() = test2.RedirectedClass.named;
}

// class FieldType extends SuperClass {
//   FieldType([this.strValue = 'def']) : number = 1;
//
//   final String strValue;
//   final int number;
//   final String finalStr = 'Hello';
// }

enum ColorEnum { red, green, blue }

//
// enum EnumWithArgs {
//   red('red'),
//   green('green'),
//   blue('blue');
//
//   final String value;
//
//   constant EnumWithArgs(this.value);
// }
