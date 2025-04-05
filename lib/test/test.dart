import 'package:code_genie/test/test2.dart';

// const annotation = Annotation();

class Annotation {
  final num number;
  final String? str;
  final String str2 = 'Hello';

  const Annotation(this.number, {this.str});
}

class Utils {
  static void targetFunc<T>() {}

  static const constFunc = Utils2.constFunc2;
}

class Utils2 {
  static const constFunc2 = Utils.targetFunc;
}

// final constFun = Utils.constFunc;

@Annotation(1, str: 'Hello')
class TestClass {
  final String str = 'Hello';
}

// @Annotation()
// class AnnotatedClass {
//   final FieldType type = FieldType();
//   final String name = constVar;
//   final int age = 30;
//   final bool isAlive = true;
//   final List<String> list = [];
//   final double height = 5.6;
//   final ColorEnum color = ColorEnum.red;
//   void x;
//   dynamic dynamicField;
//
//   // AnnotatedClass(this.type, this.name, this.age, this.isAlive);
//
//   void method() {}
// }

class FieldType extends SuperClass {
  FieldType();
}

class IrrelevantClass {
  IrrelevantClass();
}

enum ColorEnum { red, green, blue }

//
// enum EnumWithArgs {
//   red('red'),
//   green('green'),
//   blue('blue');
//
//   final String value;
//
//   const EnumWithArgs(this.value);
// }
