class Annotation {
  const Annotation();
}

@Annotation()
class AnnotatedClass {
  final String name;

  AnnotatedClass(this.name);

  void method() {
    print('Hello, $name!');
  }
}
