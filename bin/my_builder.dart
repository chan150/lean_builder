import 'dart:async';

import 'package:lean_builder/src/builder/build_step.dart';
import 'package:lean_builder/src/builder/builder.dart';
import 'package:lean_builder/src/builder/builder_impl.dart';
import 'package:lean_builder/src/builder/generator/generator.dart';
import 'package:lean_builder/src/resolvers/element/element.dart';
import 'package:lean_builder/src/resolvers/resolver.dart';
import 'package:lean_builder/src/resolvers/type/type_checker.dart';

Builder myBuilder(BuilderOptions options) {
  return SharedPartBuilder([MyGenerator()]);
}

class MyGenerator extends GeneratorForAnnotation {
  @override
  TypeChecker buildTypeChecker(Resolver resolver) {
    // return resolver.typeCheckerFor('JsonSerializable', 'package:json_annotation/json_annotation.dart');
    return resolver.typeCheckerFor('Genix', 'package:lean_builder/test/genix.dart');
  }

  @override
  FutureOr<String?> generateForAnnotatedElement(BuildStep buildStep, AnnotatedElement annotatedElement) async {
    final clazz = annotatedElement.element;
    if (clazz is! ClassElement) {
      throw Exception('Expected a ClassElement, but got ${clazz.runtimeType}');
    }
    final resolver = buildStep.resolver;
    // Perform your code generation logic here
    // For example, you can generate a class based on the annotation
    final generatedCode = StringBuffer();
    generatedCode.writeln('// Generated code for ${clazz.name}');
    generatedCode.writeln('class ${clazz.name}Generated {');
    for (final field in clazz.fields) {
      generatedCode.writeln('  final ${field.type} ${field.name};');
    }
    generatedCode.writeln('  ${clazz.name}Generated({');
    for (final field in clazz.fields) {
      generatedCode.writeln('    required this.${field.name},');
    }
    generatedCode.writeln('  });');
    generatedCode.writeln('}');

    return generatedCode.toString();
  }
}
