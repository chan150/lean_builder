// const annotation = Annotation();

class Annotation {
  // final String? str;
  // final String str2 = 'Hello';
  //
  // const Annotation(this.number, {this.str});
  const Annotation();
}
//
// class Utils {
//   static const String str = 'Hello';
// }
//
// const constVar = Utils.str;

// @Annotation(1, str: 'str')
// class TestClass {
//   final String str = 'Hello';
// }
// typedef GenericTypeDef<T, S> = Map<Set<T>, S>;
// typedef FunctionTypeDef = int Function(String str, {int? number});
// typedef FunctionGenericTypeDef<T> = T Function(T str);
// typedef InterfaceTypeDef = List<String>;
// typedef bool ElementPredicate<E>(E element);

extension type const BaselineOffset(double? offset) {}

extension StringX on String {
  String get str => 'Hello';
}

@Annotation()
class AnnotatedClass {
  AnnotatedClass();
  final BaselineOffset name;
  // final Target target;
  // final Future futre;
  // final Function func = funcDecl;
  // final FieldType type = FieldType('Hello', 1);

  // final List<String> list = ['one', 'two', 'three'];
  // final double height = 5.6;
  // final ColorEnum color = ColorEnum.red;
  // void x;
  // dynamic dynamicField;

  // // AnnotatedClass(this.type, this.name, this.age, this.isAlive);
  //
  // void method([String x = 'default']) {}

  // factory AnnotatedClass.redirected() = RedirectedClass.red;
  //
  // factory AnnotatedClass.redirected2() = AnnotatedClass;
}

// class FieldType extends SuperClass {
//   FieldType([this.strValue = 'def']) : number = 1;
//
//   final String strValue;
//   final int number;
//   final String finalStr = 'Hello';
// }

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
