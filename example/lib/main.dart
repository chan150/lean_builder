import 'package:example/src/annotations.dart';

part 'main.g.dart';

@Serializable('SSS')
class SampleX {
  final String name;
  final int age33233331 = 1222434343343222;

  SampleX(this.name);
}

@Serializable('sdfd')
class Sample2 {
  final Sample2 sample;

  Sample2(this.sample);
}
