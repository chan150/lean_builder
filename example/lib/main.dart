import 'package:json_annotation/json_annotation.dart';

part 'main.g.dart';

@ArgConverter()
@JsonSerializable()
class SampleX {
  // final int age33233331 = 1222434343343222;
  @JsonKey()
  final Arg x, y;

  // static const Arg arg = Arg(1);
  @JsonKey(defaultValue: 'defaultV')
  final String t;

  const SampleX(this.x, this.y, [this.t = 'Text']);
}

Arg serialize(int sample) {
  return Arg(sample);
}

class Arg {
  const Arg(this.x);

  final int x;
}

class ArgConverter implements JsonConverter<Arg, int> {
  const ArgConverter();

  @override
  Arg fromJson(int json) => Arg(json);

  @override
  int toJson(Arg object) => object.x;
}
