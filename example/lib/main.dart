import 'package:example/src/annotations.dart';
import 'package:json_annotation/json_annotation.dart';

part 'main.g.dart';

@Serializable()
@JsonSerializable()
class SampleX {
  @JsonKey()
  final String r;

  const SampleX([this.r = 'T233t']);
}
