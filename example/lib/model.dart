import 'package:example/src/annotations.dart';
import 'package:json_annotation/json_annotation.dart';

part 'model.g.dart';

// hello fsd234444
@Serializable()
@JsonSerializable()
class Model {
  final String name;
  final int age;
  final bool isActive;

  Model({required this.name, required this.age, required this.isActive});

  factory Model.fromJson(Map<String, dynamic> json) => _$ModelFromJson(json);

  Map<String, dynamic> toJson() => _$ModelToJson(this);
}
