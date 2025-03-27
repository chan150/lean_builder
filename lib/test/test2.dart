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
