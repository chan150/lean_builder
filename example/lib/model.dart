import 'package:example/main.dart';
import 'package:example/src/annotations.dart';

part 'model.g.dart';


@Serializable()
class Model {
  final String namex;
  final int age;
  final bool isActive;
  final String surname;
  final String xxx;
  final SampleX sample;

}
