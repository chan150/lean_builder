import 'dart:async';

import 'package:lean_builder/src/builder/build_step.dart';
import 'package:lean_builder/src/resolvers/element/element.dart';
import 'package:lean_builder/src/resolvers/resolver.dart';
import 'package:lean_builder/src/resolvers/type/type_checker.dart';

/// A tool to generate Dart code based on a Dart library source.
///
/// During a build [generate] is called once per input library.
abstract class Generator {
  const Generator();

  /// Generates Dart code for an input Dart library.
  ///
  /// May create additional outputs through the `buildStep`, but the 'primary'
  /// output is Dart code returned through the Future. If there is nothing to
  /// generate for this library may return null, or a Future that resolves to
  /// null or the empty string.
  FutureOr<String?> generate(LibraryElement library, BuildStep buildStep) => null;

  @override
  String toString() => runtimeType.toString();
}

abstract class GeneratorForAnnotation extends Generator {
  final bool throwOnUnresolved;

  /// By default, this generator will throw if it encounters unresolved
  /// annotations. You can override this by setting [throwOnUnresolved] to
  /// `false`.
  GeneratorForAnnotation({this.throwOnUnresolved = true});

  TypeChecker? _typeChecker;

  TypeChecker _getTypeChecker(BuildStep buildStep) {
    return _typeChecker ??= buildTypeChecker(buildStep.resolver);
  }

  @override
  FutureOr<String> generate(LibraryElement library, BuildStep buildStep) async {
    final typeChecker = _getTypeChecker(buildStep);
    final values = <String>{};
    final annotatedElements = library.annotatedWith(typeChecker);
    if (annotatedElements.isEmpty && throwOnUnresolved) {
      throw ArgumentError(
        'No elements found with annotation $typeChecker in ${library.src.uri}. '
        'Please check your annotations.',
      );
    }
    for (var annotatedElement in annotatedElements) {
      final rawValue = generateForAnnotatedElement(buildStep, annotatedElement);
      final value = rawValue is Future ? await rawValue : rawValue;
      if (value != null && value.trim().isNotEmpty) {
        values.add(value);
      }
    }
    return values.join('\n\n');
  }

  TypeChecker buildTypeChecker(Resolver resolver);

  FutureOr<String?> generateForAnnotatedElement(BuildStep buildStep, AnnotatedElement annotatedElement);
}

class SimpleGeneratorForAnnotation extends GeneratorForAnnotation {
  final TypeChecker Function(Resolver resolver) _buildTypeChecker;
  final FutureOr<String?> Function(BuildStep buildStep, AnnotatedElement annotatedElement) _generateForAnnotatedElement;

  SimpleGeneratorForAnnotation(this._buildTypeChecker, this._generateForAnnotatedElement);

  @override
  TypeChecker buildTypeChecker(Resolver resolver) {
    return _buildTypeChecker(resolver);
  }

  @override
  FutureOr<String?> generateForAnnotatedElement(BuildStep buildStep, AnnotatedElement annotatedElement) {
    return _generateForAnnotatedElement(buildStep, annotatedElement);
  }
}
