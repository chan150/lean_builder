import 'package:code_genie/test/test2.dart';

const annotation = Annotation();

class Annotation {
  const Annotation();
}

class Utils {
  static void targetFunc<T>() {}
}

class Utils2 {
  static const constFunc2 = Utils.targetFunc;
}

// const constVar = 'constVar';
//
// const constFunc = Utils.targetFunc;

@annotation
class TestClass {
  // void method1() {}
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
//
// class FieldType extends SuperClass {
//   FieldType();
// }
//
// class IrrelevantClass {
//   IrrelevantClass();
// }
//
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
