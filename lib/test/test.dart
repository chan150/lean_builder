import 'package:code_genie/test/test2.dart';

class Annotation {
  // final String? str;
  // final String str2 = 'Hello';
  //
  // const Annotation(this.number, {this.str});
  const Annotation();
}

//
// @Annotation()
// class Widgets extends StatelessWidget {
//   const Widgets({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return throw UnimplementedError();
//   }
// }
//
// @Annotation()
// class Widgets2 extends StatelessWidget {
//   const Widgets2({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return throw UnimplementedError();
//   }
// }

typedef RecordType<T> = (T x, int y);
typedef ValueChanged<T> = T? Function(T value, {T? value2});

@Annotation()
class AnnotatedClass {
  AnnotatedClass(this.record);

  final RecordType record;

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
