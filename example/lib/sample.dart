import 'package:example/src/annotations.dart';

part 'sample.g.dart';

@Serializable2()
@Serializable()
class SomeClass {
  final String name;
  final int age8 = 233333323222;

  SomeClass(this.name);
}
