import 'package:json_annotation/json_annotation.dart';

part 'main.g.dart';

@JsonSerializable()
/// 2222234f22qw223232323
class SampleX {
  @JsonKey()
  @JsonKey(defaultValue: 'defaultV')
  final String r;

  const SampleX([this.r = 'Text']);
}
