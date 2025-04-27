import 'dart:async';

import 'package:lean_builder/builder.dart';
import 'package:lean_builder/type.dart';
import 'package:lean_builder/element.dart';

Builder serializationBuilder2(BuilderOptions options) {
  return LibraryBuilder(SerializationGenerator2(), outputExtensions: {'.lib.dart'});
}

class SerializationGenerator2 extends GeneratorForAnnotation {
  @override
  TypeChecker buildTypeChecker(Resolver resolver) {
    return resolver.typeCheckerFor('Serializable2', 'package:example/src/annotations.dart');
  }

  @override
  FutureOr<String?> generateForAnnotatedElement(BuildStep buildStep, AnnotatedElement annotatedElement) async {
    final element = annotatedElement.element;
    if (element is! ClassElement) {
      throw Exception('Expected a class element, but got ${element.runtimeType} in ${buildStep.asset.shortUri}');
    }

    final buffer = StringBuffer();

    buffer.writeln('class ${element.name}Lib {');
    for (final field in element.fields) {
      buffer.writeln('final ${field.type} ${field.name};');
    }
    buffer.writeln('${element.name}Lib({');
    for (final field in element.fields) {
      buffer.writeln('required this.${field.name},');
    }
    buffer.writeln('});');
    buffer.writeln('}');

    return buffer.toString();
  }
}
