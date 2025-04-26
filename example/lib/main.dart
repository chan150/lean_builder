import 'package:example/src/annotations.dart';

part 'main.g.dart';

@Serializable()
class Sample {
  final Sample sample;
  final String name;
  final int age82323 = 43333;

  Sample(this.sample, this.name);
}

@Serializable()
class Sample2 {
  final Sample2 sample;

  Sample2(this.sample);
}
