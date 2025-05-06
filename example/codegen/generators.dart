import 'dart:convert';

import 'package:example/src/annotations.dart';
import 'package:lean_builder/builder.dart';

@LeanGenerator({'.config.json'}, generateToCache: true)
class SerializableGenerator extends GeneratorForAnnotatedClass<Serializable> {
  @override
  Future<String> generateForClass(buildStep, element, annotation) async {
    // final buffer = StringBuffer();
    // buffer.writeln('class Gen${element.name} {');
    // for (final field in element.fields) {
    //   buffer.writeln('final ${field.type} ${field.name};');
    // }
    // buffer.writeln('}');

    return jsonEncode({'name': element.name});
  }
}
