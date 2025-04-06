import 'package:code_genie/test/test.dart';

class TypeT extends RoutePage {}

class RoutePage {
  const RoutePage();
}

class SuperClass extends SuperSuperClass<int> {
  void superMethod() {}
}

class SuperSuperClass<T> {
  void superSuperMethod() {}
}

class Utils {
  static const value = Utils.value0;

  static const value0 = 'value0';
}

class RedirectedClass extends AnnotatedClass {
  RedirectedClass.red();
}
