import 'package:example/main.dart';
import 'package:example/src/annotations.dart';

@Serializable('Model')
class Model {
  final String namex;
  final int age;
  final bool isActive;
  final String surname;
  final String xxx;
  final SampleX sample;

  Model(this.namex, this.age, this.isActive, this.surname, this.xxx, this.sample);
}
