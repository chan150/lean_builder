class Annotation {
  // final String? str;
  // final String str2 = 'Hello';
  //
  // const Annotation(this.number, {this.str});
  const Annotation();
}

class SuperClass2<T> {
  final List<T> list;
  const SuperClass2(this.list, {String? x});
}

class SuperClass extends SuperClass2 {
  const SuperClass(super.list2);
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

@Annotation()
class AnnotatedClass extends SuperClass2 {
  AnnotatedClass(super.diffListName);

  // final Target target;
  // final Future futre;
  // List<Set<String>> list = [];
  // // final FieldType type = FieldType('Hello', 1);
  //
  // // final List<String> list = ['one', 'two', 'three'];
  // final double height = 5.6;
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
