import 'package:code_genie/test/test2.dart';

part 'test_part.dart';

@RoutePage()
@Annotation()
class A extends XX {
  A(this.x);
  final PartX x;
  void method() {}
}

class Annotation {
  const Annotation();
}
