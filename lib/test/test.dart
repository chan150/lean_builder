import 'package:code_genie/test/test2.dart';

class Genix$ {
  final String? str;
  final String? str2;

  // const Annotation(this.number, {this.str});
  const Genix$(this.str, {this.str2 = 'Hello'});
  const Genix$.named(this.str) : str2 = null;
}

const genix$ = Genix$.named('Hello');

const varConst = 'Hello';

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
// @annotation
const constArg = 'Hello';

@varConst
@genix$
@Genix$('Argument', str2: constArg)
class AnnotatedClass {
  AnnotatedClass(this.fieldType);
  final FieldType fieldType;
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
