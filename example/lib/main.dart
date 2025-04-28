import 'package:example/src/annotations.dart';

part 'main.g.dart';

@Serializable('SSS')
class SampleX {
  final String name;
  final int age3321 = 1222222;

  SampleX(this.name);
}

@Serializable('sdfd')
class Sample2 {
  final Sample2 sample;

  Sample2(this.sample);
}
