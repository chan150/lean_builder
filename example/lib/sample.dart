import 'package:example/src/annotations.dart';

part 'sample.g.dart';

@Serializable()
class SomeClass {
  final String name;
  final int age8 = 2;

  SomeClass(this.name);
}
