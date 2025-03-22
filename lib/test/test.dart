import 'package:code_genie/test/test2.dart';

part 'test_part.dart';

@Annotation()
class A extends XX {
  A(this.x);

  final PartX x;

  final String xxx = '2323ee223';

  void method() {}
}

class Annotation {
  const Annotation();
}

enum EnumX { A, B, C }

const constVar = 42;
final finalVar = 42;
late final lateFinalVar;

//
// mixin MixinX {
//   void method() {}
// }
//
// final topLevelVarFinal = 42;
// late final topLevelVarLateFinal;
//
// int topLevelTypedCore = 42;
//
// EnumX topLevelEnumX = EnumX.A;
//
// void topLevelFunction() {}
//
// int topLevelFunctionWithParams(int x, int y) => x + y;
//
// EnumX topLevelFunctionWithReturn() => EnumX.A;
// final closure = () => 42;
