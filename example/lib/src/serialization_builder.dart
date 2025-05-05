import 'dart:async';

import 'package:example/src/annotations.dart';
import 'package:lean_builder/builder.dart';
import 'package:lean_builder/type.dart';
import 'package:lean_builder/element.dart';

// Builder serializationBuilder(BuilderOptions options) {
//   return SharedPartBuilder([SerializationGenerator()]);
// }
//
// // hello23
// class SerializationGenerator extends GeneratorForAnnotationBase {
//   @override
//   TypeChecker buildTypeChecker(Resolver resolver) {
//     return resolver.typeCheckerFor('Serializable', 'package:example/src/annotations.dart');
//     // return resolver.typeCheckerFor('JsonSerializable', 'package:json_annotation/json_annotation.dart');
//   }
//
//   @override
//   FutureOr<String?> generateForAnnotatedElement(
//     BuildStep buildStep,
//     Element element,
//     ElementAnnotation annotation,
//   ) async {
//     if (element is! ClassElement) {
//       throw Exception('Expected a class element, but got ${element.runtimeType}');
//     }
//     final buffer = StringBuffer();
//     buffer.writeln('class ${element.name}Serializer {');
//     for (final field in element.fields) {
//       buffer.writeln('final ${field.type} ${field.name};');
//     }
//     buffer.writeln('${element.name}Serializer({');
//     for (final field in element.fields) {
//       buffer.writeln('required this.${field.name},');
//     }
//     buffer.writeln('});');
//     buffer.writeln('}');
//     buffer.writeln('// hello world33333');
//     return buffer.toString();
//   }
// }
