import 'package:example/src/annotations.dart';
import 'package:json_annotation/json_annotation.dart';

part 'main.g.dart';

@Serializable()
@JsonSerializable()
class SampleX {
  @JsonKey()
  @JsonKey()
  final String rrrr;

  const SampleX([this.rrrr = 'Text']);
}
