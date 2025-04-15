import 'package:code_genie/test/test2.dart';

class SuperX {
  const SuperX({this.superStr = 'superStr'});

  final String superStr;
}

typedef TypedType = void Function(int x, bool y);

class Genix$ extends SuperX {
  final Type type;
  final String? str2;
  final String Function(int x, bool y)? func;

  const Genix$(this.type, {super.superStr = 'SuperStr2', this.func}) : str2 = 'str2';

  const Genix$.named(this.type, this.func) : str2 = null;

  // static const Genix$ named2 = Genix$('Hello', str2: 'Hello', superStr: 'Hello');
}

const varConst = 'Hello';

// const genix$ = Genix$.named('Hello', null);

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

String doStuff(int x, bool y) {
  return 'Hello';
}

@Genix$(TypedType, func: doStuff)
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
