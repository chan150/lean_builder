import 'package:lean_builder/test/test.dart';

const constVar = 'Hello';

class FieldType<T> {
  final List<T>? value;
  const FieldType(this.value);
  static const instance = FieldType(null);
}

class SuperX {
  const SuperX({this.superStr = 'superStr'});

  final String superStr;

  const SuperX.named({this.superStr = 'superStr'});
}

class RedirectedClass extends AnnotatedClass {
  RedirectedClass() : super('');
  RedirectedClass.red() : super('');
  RedirectedClass.named() : super('');
}
