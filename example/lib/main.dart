import 'package:example/src/annotations.dart';
import 'package:json_annotation/json_annotation.dart';

@Serializable()
class SampleX {
  @JsonKey()
  final String r;

  final String? t;

  const SampleX(this.t, [this.r = 'T233']);
}
