import 'package:lean_builder/builder.dart';
import 'package:meta/meta_meta.dart' show TargetKind, Target;

/// A collection of annotation names used by the lean_builder package.
const Set<String> kBuilderAnnotationNames = <String>{
  'LeanBuilder',
  'LeanGenerator',
  'LeanBuilderOverrides',
};

/// Annotation for defining a build-time builder.
///
/// Classes annotated with `LeanBuilder` are recognized by the build system
/// and will be instantiated to process source files during the build process.
@Target(<TargetKind>{TargetKind.classType})
class LeanBuilder {
  /// Optional unique identifier for this builder.
  final String? key;

  /// Whether output should be cached.
  /// If true, the builder's output will be stored in the build cache.
  final bool? generateToCache;

  /// Glob patterns specifying which files this builder should process.
  final Set<String>? generateFor;

  /// Builder keys that should run before this builder.
  final Set<String>? runsBefore;

  /// {@template lean_builder_register_types}
  /// The Types this builder intends to uses for type checking.
  ///
  /// these types will be fed to the resolver at build time to mimic
  /// creating a type checker from runtime types.
  ///
  /// this exists because the lean_builder package aims
  /// to not depend on reflections at all.
  /// {@endtemplate}
  final Set<Type>? registerTypes;

  /// Additional configuration options for this builder.
  final Map<String, dynamic>? options;

  /// The default constructor
  const LeanBuilder({
    this.key,
    this.registerTypes,
    this.generateToCache,
    this.generateFor,
    this.runsBefore,
    this.options,
  });
}

/// Annotation for defining a code generator.
///
/// Classes annotated with `LeanGenerator` will be used to generate code
/// during the build process. Generators typically transform input files
/// into output files with specified extensions.
@Target(<TargetKind>{TargetKind.classType})
class LeanGenerator {
  /// Optional unique identifier for this generator.
  final String? key;

  /// Whether output should be cached.
  /// If true, the generator's output will be stored in the build cache.
  final bool? generateToCache;

  /// Glob patterns specifying which files this generator should process.
  final Set<String>? generateFor;

  /// Generator keys that should run before this generator.
  final Set<String>? runsBefore;

  /// Builder keys that this generator applies to.
  final Set<String>? applies;

  /// {@macro lean_builder_register_types}
  final Set<Type>? registerTypes;

  /// File extensions this generator will produce.
  final Set<String> outputExtensions;

  /// Whether to continue processing even when syntax errors are present.
  final bool? allowSyntaxErrors;

  /// Additional configuration options for this generator.
  final Map<String, dynamic>? options;

  /// Creates a generator that's used by [LibraryBuilder]
  const LeanGenerator(
    this.outputExtensions, {
    this.key,
    this.allowSyntaxErrors,
    this.generateToCache,
    this.registerTypes,
    this.generateFor,
    this.runsBefore,
    this.options,
    this.applies,
  });

  /// Creates a generator that's used by [SharedPartBuilder]
  const LeanGenerator.shared({
    this.key,
    this.allowSyntaxErrors,
    this.applies,
    this.registerTypes,
    this.generateFor,
    this.runsBefore,
    this.options,
  }) : outputExtensions = const <String>{},
       generateToCache = false;
}

/// Annotation for specifying builder overrides at the top level.
///
/// Variables annotated with `LeanBuilderOverrides` can be used to
/// customize the behavior of builders during the build process.
@Target(<TargetKind>{TargetKind.topLevelVariable})
class LeanBuilderOverrides {
  /// The default constructor
  const LeanBuilderOverrides();
}
