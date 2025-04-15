import 'package:code_genie/test/test.dart';

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
  const RedirectedClass() : super(FieldType.instance);
  const RedirectedClass.red() : super(FieldType.instance);
  const RedirectedClass.named() : super(FieldType.instance);
}
