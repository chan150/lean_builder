import 'dart:async';

import 'package:lean_builder/builder.dart';
import 'package:lean_builder/type.dart';
import 'package:lean_builder/element.dart';

Builder serializationBuilder(BuilderOptions options) {
  return SharedPartBuilder([SerializationGenerator()]);
}

class SerializationGenerator extends GeneratorForAnnotation {
  @override
  TypeChecker buildTypeChecker(Resolver resolver) {
    return resolver.typeCheckerFor('Serializable', 'package:example/src/annotations.dart');
  }

  @override
  FutureOr<String?> generateForAnnotatedElement(BuildStep buildStep, AnnotatedElement annotatedElement) async {
    final element = annotatedElement.element;
    if (element is! ClassElement) {
      throw Exception('Expected a class element, but got ${element.runtimeType}');
    }
    final buffer = StringBuffer();
    buffer.writeln('// ${annotatedElement.annotation.constant.toString()}');
    buffer.writeln('class ${element.name}Serializer {');
    for (final field in element.fields) {
      buffer.writeln('final ${field.type} ${field.name};');
    }
    buffer.writeln('${element.name}Serializer({');
    for (final field in element.fields) {
      buffer.writeln('required this.${field.name},');
    }
    buffer.writeln('});');
    buffer.writeln('}');

    return buffer.toString();
  }
}
