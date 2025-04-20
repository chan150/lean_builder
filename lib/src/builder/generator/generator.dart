import 'package:async/async.dart';
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
    for (var annotatedElement in library.annotatedWith(typeChecker)) {
      final generatedValue = generateForAnnotatedElement(buildStep, annotatedElement);
      await for (var value in _normalizeGeneratorOutput(generatedValue)) {
        assert(value.length == value.trim().length);
        values.add(value);
      }
    }

    return values.join('\n\n');
  }

  TypeChecker buildTypeChecker(Resolver resolver);

  FutureOr<String?> generateForAnnotatedElement(BuildStep buildStep, AnnotatedElement annotatedElement);

  /// Converts [Future], [Iterable], and [Stream] implementations
  /// containing [String] to a single [Stream] while ensuring all thrown
  /// exceptions are forwarded through the return value.
  Stream<String> _normalizeGeneratorOutput(Object? value) {
    if (value == null) {
      return const Stream.empty();
    } else if (value is Future) {
      return StreamCompleter.fromFuture(value.then(_normalizeGeneratorOutput));
    } else if (value is String) {
      value = [value];
    }

    if (value is Iterable) {
      value = Stream.fromIterable(value);
    }

    if (value is Stream) {
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
}
