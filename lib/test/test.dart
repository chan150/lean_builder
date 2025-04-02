import 'package:code_genie/test/test2.dart';

class Annotation {
  const Annotation();
}

@Annotation()
class AnnotatedClass {
  // final FieldType type = FieldType();
  // final String name = 'John Doe';
  // final int age = 30;
  // final bool isAlive = true;
  // final List<String> list = [];
  // final double height = 5.6;
  // final ColorEnum color = ColorEnum.red;
  // void x;
  // dynamic dynamicField;
  String Function(String param1) functionField = (_) {
    return 'Hello';
  };

  T Function<T>()? genericFunctionField;
  // AnnotatedClass(this.type, this.name, this.age, this.isAlive);

  void method() {}
}

void func(String name) {}

class FieldType extends SuperClass {
  FieldType();
}

class IrrelevantClass {
  IrrelevantClass();
}

enum ColorEnum { red, green, blue }

enum EnumWithArgs {
  red('red'),
  green('green'),
  blue('blue');

  final String value;

  const EnumWithArgs(this.value);
}
