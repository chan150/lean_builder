import 'package:example/src/annotations.dart';
import 'package:meta/meta.dart';

part 'main.g.dart';

@immutable
@Serializable2()
@Serializable()
class SampleX {
  final String name;
  final int age42123 = 123222222;

  SampleX(this.name);
}

@Serializable2()
@Serializable()
class Sample2 {
  final Sample2 sample;

  Sample2(this.sample);
}
