// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Model _$ModelFromJson(Map<String, dynamic> json) => Model(
      name: json['name'] as String,
      age: (json['age'] as num).toInt(),
      isActive: json['isActive'] as bool,
    );

Map<String, dynamic> _$ModelToJson(Model instance) => <String, dynamic>{
      'age': instance.age,
      'name': instance.name,
      'isActive': instance.isActive,
    };

// **************************************************************************
// SerializationGenerator
// **************************************************************************

class ModelSerializer {
  final String name;
  final int age;
  final bool isActive;
  ModelSerializer({
    required this.name,
    required this.age,
    required this.isActive,
  });
}

// hello world

