import 'dart:async';

import 'package:lean_builder/src/builder/build_step.dart';
import 'package:lean_builder/src/builder/generator/generator.dart';
import 'package:lean_builder/src/resolvers/element/element.dart';
import 'package:lean_builder/src/resolvers/resolver.dart';
import 'package:lean_builder/src/resolvers/type/type_checker.dart';

class MyGenerator extends GeneratorForAnnotation {
  MyGenerator();

  @override
  TypeChecker buildTypeChecker(Resolver resolver) {
    return resolver.typeCheckerFor('JsonSerializable', 'package:json_annotation/json_annotation.dart');
  }

  @override
  FutureOr<String?> generateForAnnotatedElement(BuildStep buildStep, AnnotatedElement annotatedElement) {
    final clazz = annotatedElement.element;
    if (clazz is! ClassElement) {
      throw Exception('Expected a ClassElement, but got ${clazz.runtimeType}');
    }

    // Perform your code generation logic here
    // For example, you can generate a class based on the annotation

    final generatedCode = '''
      // Generated code for ${clazz.name}
      class ${clazz.name}Generated {
        // Your generated code here
      }
    ''';
    return generatedCode;
  }
}
