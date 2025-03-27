import 'package:code_genie/test/test2.dart';

class Annotation {
  const Annotation();
}

@Annotation()
class AnnotatedClass {
  final FieldType type;
  final String name;
  final int age;
  final bool isAlive;
  final List<String> list = [];
  final double height = 5.6;

  AnnotatedClass(this.type, this.name, this.age, this.isAlive);

  void method() {}
}

class FieldType extends SuperClass {
  FieldType();
}

class IrrelevantClass {
  IrrelevantClass();
}
