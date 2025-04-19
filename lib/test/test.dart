import 'package:lean_builder/test/annotation.dart';
import 'package:lean_builder/test/test2.dart' as test2;
import 'package:lean_builder/test/test2.dart';

typedef TypedType = void Function(int x, bool y);

abstract base class X {}

const String constArg = 'Hello';

const constVar = 'Hello';

// @Genix<String>(ObjectArg('arg'))
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

class SuperGenix extends Genix<String> {
  const SuperGenix(super.arg);
}

@SuperGenix('XXX')
@Genix<String>('Hello')
class AnnotatedClass {
  AnnotatedClass(this._namex);

  String _namex = 'Hello';

  String get name => 0 == 1 ? '' : "43";

  set name(String value) {
    _namex = value;
  }

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
