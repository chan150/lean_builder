import 'dart:async' show FutureOr;

import 'package:lean_builder/builder.dart';
import 'package:lean_builder/src/element/element.dart';
import 'package:lean_builder/src/type/type_checker.dart';

/// {@template generator}
/// A tool to generate Dart code based on a Dart library source.
///
/// During a build [generate] is called once per input library.
/// {@endtemplate}
abstract class Generator {
  /// {@template generator.constructor}
  /// Creates a generator instance.
  /// {@endtemplate}
  const Generator();

  /// {@template generator.generate}
  /// Generates Dart code for an input Dart library.
  ///
  /// May create additional outputs through the `buildStep`, but the 'primary'
  /// output is Dart code returned through the Future. If there is nothing to
  /// generate for this library may return null, or a Future that resolves to
  /// null or the empty string.
  ///
  /// @param library The library element to generate code for
  /// @param buildStep The build step providing context for generation
  /// @return Generated code as a string, or null if nothing to generate
  /// {@endtemplate}
  FutureOr<String?> generate(LibraryElement library, BuildStep buildStep) => null;

  @override
  String toString() => runtimeType.toString();
}

/// {@template generator_for_annotation_base}
/// Base class for generators that process elements with specific annotations.
///
/// This abstract class provides core functionality for finding annotated
/// elements in a library and generating code for them.
/// {@endtemplate}
abstract class GeneratorForAnnotationBase extends Generator {
  /// {@template generator_for_annotation_base.throw_on_unresolved}
  /// Whether to throw an exception if no annotated elements are found.
  ///
  /// If true, the generator will throw an ArgumentError when no elements
  /// with the targeted annotation are found in the library.
  /// {@endtemplate}
  final bool throwOnUnresolved;

  /// {@template generator_for_annotation_base.constructor}
  /// Creates a generator for processing elements with specific annotations.
  ///
  /// By default, this generator will throw if it encounters unresolved
  /// annotations. You can override this by setting [throwOnUnresolved] to
  /// `false`.
  /// {@endtemplate}
  const GeneratorForAnnotationBase({this.throwOnUnresolved = false});

  /// Cache for type checkers to avoid recreating them for each generator instance.
  static final Expando<TypeChecker> _typeChecker = Expando<TypeChecker>();

  /// {@template generator_for_annotation_base.get_type_checker}
  /// Gets a TypeChecker for this generator's annotation type.
  ///
  /// Uses a cached value if available, otherwise builds a new checker
  /// using [buildTypeChecker].
  ///
  /// @param buildStep The build step providing the resolver
  /// @return A TypeChecker for this generator's annotation
  /// {@endtemplate}
  TypeChecker getTypeChecker(BuildStep buildStep) {
    return _typeChecker[this] ??= buildTypeChecker(buildStep.resolver);
  }

  @override
  FutureOr<String> generate(LibraryElement library, BuildStep buildStep) async {
    final TypeChecker typeChecker = getTypeChecker(buildStep);
    final Set<String> values = <String>{};
    final Iterable<AnnotatedElement> annotatedElements = library.annotatedWith(
      typeChecker,
    );
    if (annotatedElements.isEmpty && throwOnUnresolved) {
      throw ArgumentError(
        'No elements found with annotation $typeChecker in ${library.src.uri}. '
        'Please check your annotations.',
      );
    }
    for (AnnotatedElement annotatedElement in annotatedElements) {
      final dynamic rawValue = generateForAnnotatedElement(
        buildStep,
        annotatedElement.element,
        annotatedElement.annotation,
      );
      final Iterable<String> normalized = await normalizeGeneratorOutput(rawValue);
      for (final String value in normalized) {
        if (value.trim().isNotEmpty) {
          values.add(value);
        }
      }
    }
    return values.join('\n\n');
  }

  /// {@template generator_for_annotation_base.build_type_checker}
  /// Creates a TypeChecker for this generator's annotation type.
  ///
  /// Subclasses must implement this to provide a TypeChecker for their
  /// specific annotation type.
  ///
  /// @param resolver The resolver to use for type checking
  /// @return A TypeChecker for this generator's annotation
  /// {@endtemplate}
  TypeChecker buildTypeChecker(Resolver resolver);

  /// {@template generator_for_annotation_base.generate_for_annotated_element}
  /// Generates code for a single annotated element.
  ///
  /// This is called for each element in the library that has the annotation
  /// this generator is targeting.
  ///
  /// @param buildStep The build step providing context for generation
  /// @param element The annotated element
  /// @param annotation The annotation instance on the element
  /// @return Generated code as a string, or null if nothing to generate
  /// {@endtemplate}
  dynamic generateForAnnotatedElement(
    BuildStep buildStep,
    Element element,
    ElementAnnotation annotation,
  );
}

/// {@template generator_for_annotation}
/// A generator that processes elements with a specific annotation type.
///
/// This class uses generic type parameters to specify the annotation type,
/// making it easier to create generators for specific annotations.
/// {@endtemplate}
abstract class GeneratorForAnnotation<T> extends GeneratorForAnnotationBase {
  /// {@macro generator_for_annotation_base.constructor}
  const GeneratorForAnnotation({super.throwOnUnresolved});

  @override
  TypeChecker buildTypeChecker(Resolver resolver) {
    return resolver.typeCheckerOf<T>();
  }
}

/// {@template generator_for_annotated_class}
/// A generator that processes class elements with a specific annotation type.
///
/// This specialized generator only targets class elements and automatically
/// handles filtering out non-class elements.
/// {@endtemplate}
abstract class GeneratorForAnnotatedClass<T> extends GeneratorForAnnotation<T> {
  /// {@macro generator_for_annotation_base.constructor}
  const GeneratorForAnnotatedClass({super.throwOnUnresolved});

  @override
  TypeChecker buildTypeChecker(Resolver resolver) {
    return resolver.typeCheckerOf<T>();
  }

  @override
  dynamic generateForAnnotatedElement(
    BuildStep buildStep,
    Element element,
    ElementAnnotation annotation,
  ) {
    if (element is! ClassElement) {
      throw InvalidGenerationSourceError(
        'Expected a class element but found ${element.runtimeType}.',
        element: element,
      );
    }
    return generateForClass(buildStep, element, annotation);
  }

  /// {@template generator_for_annotated_class.generate_for_class}
  /// Generates code for an annotated class element.
  ///
  /// This is called for each class in the library that has the annotation
  /// this generator is targeting.
  ///
  /// @param buildStep The build step providing context for generation
  /// @param element The annotated class element
  /// @param annotation The annotation instance on the class
  /// @return Generated code as a string, or null if nothing to generate
  /// {@endtemplate}
  dynamic generateForClass(
    BuildStep buildStep,
    ClassElement element,
    ElementAnnotation annotation,
  );
}

/// {@template generator_for_annotated_enum}
/// A generator that processes enum elements with a specific annotation type.
///
/// This specialized generator only targets enum elements and automatically
/// handles filtering out non-enum elements.
/// {@endtemplate}
abstract class GeneratorForAnnotatedEnum<T> extends GeneratorForAnnotation<T> {
  /// {@macro generator_for_annotation_base.constructor}
  const GeneratorForAnnotatedEnum({super.throwOnUnresolved});

  @override
  TypeChecker buildTypeChecker(Resolver resolver) {
    return resolver.typeCheckerOf<T>();
  }

  @override
  dynamic generateForAnnotatedElement(
    BuildStep buildStep,
    Element element,
    ElementAnnotation annotation,
  ) {
    if (element is! EnumElement) {
      throw InvalidGenerationSourceError(
        'Expected an enum element but found ${element.runtimeType}.',
        element: element,
      );
    }
    return generateForEnum(buildStep, element, annotation);
  }

  /// {@template generator_for_annotated_enum.generate_for_enum}
  /// Generates code for an annotated enum element.
  ///
  /// This is called for each enum in the library that has the annotation
  /// this generator is targeting.
  ///
  /// @param buildStep The build step providing context for generation
  /// @param element The annotated enum element
  /// @param annotation The annotation instance on the enum
  /// @return Generated code as a string, or null if nothing to generate
  /// {@endtemplate}
  dynamic generateForEnum(
    BuildStep buildStep,
    EnumElement element,
    ElementAnnotation annotation,
  );
}

/// {@template generator_for_annotated_function}
/// A generator that processes function elements with a specific annotation type.
///
/// This specialized generator only targets function elements and automatically
/// handles filtering out non-function elements.
/// {@endtemplate}
abstract class GeneratorForAnnotatedFunction<T> extends GeneratorForAnnotation<T> {
  /// {@macro generator_for_annotation_base.constructor}
  const GeneratorForAnnotatedFunction({super.throwOnUnresolved});

  @override
  TypeChecker buildTypeChecker(Resolver resolver) {
    return resolver.typeCheckerOf<T>();
  }

  @override
  dynamic generateForAnnotatedElement(
    BuildStep buildStep,
    Element element,
    ElementAnnotation annotation,
  ) {
    if (element is! FunctionElement) {
      throw InvalidGenerationSourceError(
        'Expected a function element but found ${element.runtimeType}.',
        element: element,
      );
    }
    return generateForFunction(buildStep, element, annotation);
  }

  /// {@template generator_for_annotated_function.generate_for_function}
  /// Generates code for an annotated function element.
  ///
  /// This is called for each function in the library that has the annotation
  /// this generator is targeting.
  ///
  /// @param buildStep The build step providing context for generation
  /// @param element The annotated function element
  /// @param annotation The annotation instance on the function
  /// @return Generated code as a string, or null if nothing to generate
  /// {@endtemplate}
  dynamic generateForFunction(
    BuildStep buildStep,
    FunctionElement element,
    ElementAnnotation annotation,
  );
}

/// {@template normalize_generator_output}
/// Converts [Future], [Iterable], or [String] to a normalized output.
///
/// Handles various return types from generators and converts them to a
/// consistent format: an Iterable of non-empty strings.
///
/// @param value The value to normalize
/// @return A Future that resolves to an Iterable of normalized strings
/// @throws ArgumentError if the value cannot be normalized
/// {@endtemplate}
Future<Iterable<String>> normalizeGeneratorOutput(Object? value) async {
  if (value == null) {
    return Future<Iterable<String>>.value(const Iterable<String>.empty());
  } else if (value is Future) {
    return value.then(normalizeGeneratorOutput);
  } else if (value is String) {
    value = <String>[value];
  }

  if (value is Iterable) {
    return value
        .where((dynamic e) => e != null)
        .map((dynamic e) {
          if (e is String) {
            return e.trim();
          }
          throw _argError(e as Object);
        })
        .where((String e) => e.isNotEmpty);
  }

  throw _argError(value);
}

/// Creates an ArgumentError for invalid generator output.
ArgumentError _argError(Object value) => ArgumentError(
  'Must be a String or be an Iterable/Stream containing String values. '
  'Found `${Error.safeToString(value)}` (${value.runtimeType}).',
);
