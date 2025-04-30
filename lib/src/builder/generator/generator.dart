import 'dart:async';

import 'package:lean_builder/src/builder/build_step.dart';
import 'package:lean_builder/src/element/element.dart';
import 'package:lean_builder/src/resolvers/resolver.dart';
import 'package:lean_builder/src/type/type_checker.dart';

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
  GeneratorForAnnotation({this.throwOnUnresolved = false});

  TypeChecker? _typeChecker;

  TypeChecker getTypeChecker(BuildStep buildStep) {
    return _typeChecker ??= buildTypeChecker(buildStep.resolver);
  }

  @override
  FutureOr<String> generate(LibraryElement library, BuildStep buildStep) async {
    final typeChecker = getTypeChecker(buildStep);
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
      final normalized = await normalizeGeneratorOutput(rawValue);
      for (final value in normalized) {
        if (value.trim().isNotEmpty) {
          values.add(value);
        }
      }
    }
    return values.join('\n\n');
  }

  TypeChecker buildTypeChecker(Resolver resolver);

  dynamic generateForAnnotatedElement(BuildStep buildStep, AnnotatedElement annotatedElement);
}

/// Converts [Future], [Iterable], or [String] to a normalized output.
Future<Iterable<String>> normalizeGeneratorOutput(Object? value) async {
  if (value == null) {
    return Future.value(const Iterable.empty());
  } else if (value is Future) {
    return value.then(normalizeGeneratorOutput);
  } else if (value is String) {
    value = [value];
  }

  if (value is Iterable) {
    return value
        .where((e) => e != null)
        .map((e) {
          if (e is String) {
            return e.trim();
          }
          throw _argError(e as Object);
        })
        .where((e) => e.isNotEmpty);
  }

  throw _argError(value);
}

ArgumentError _argError(Object value) => ArgumentError(
  'Must be a String or be an Iterable/Stream containing String values. '
  'Found `${Error.safeToString(value)}` (${value.runtimeType}).',
);
