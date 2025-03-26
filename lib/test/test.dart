class Annotation {
  const Annotation();
}

@Annotation()
class AnnotatedClass {
  final FieldType type;
  AnnotatedClass(this.type);

  void method() {}
}

class FieldType {
  FieldType();
}
