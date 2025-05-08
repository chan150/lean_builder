import 'dart:async' show FutureOr;

import 'package:lean_builder/builder.dart';
import 'package:glob/glob.dart' show Glob;
import 'package:lean_builder/src/asset/asset.dart';
import 'package:lean_builder/src/resolvers/resolver.dart';

/// {@template generator_factory}
/// Creates a [Generator] with the given [options].
///
/// This typedef defines a function that instantiates a [Generator] with specific
/// configuration options. This allows for flexible creation of generators
/// with different configurations.
/// {@endtemplate}
typedef GeneratorFactory = Generator Function(BuilderOptions options);

/// {@template builder_factory}
/// Creates a [Builder] honoring the configuration in [options].
///
/// This typedef defines a function that instantiates a [Builder] with specific
/// configuration options. This allows for flexible creation of builders
/// with different configurations.
/// {@endtemplate}
typedef BuilderFactory = Builder Function(BuilderOptions options);

/// {@template builder_entry}
/// An abstract class representing a builder configuration and its execution context.
///
/// [BuilderEntry] defines the interface for configuring and executing builders
/// during the build process. It encapsulates:
/// - The builder's unique identifier
/// - Its output configuration (cache vs in-source)
/// - Filtering rules for which files it should process
/// - Dependency relationships with other builders
/// - Methods for builder execution and preparation
///
/// This abstraction allows the build system to handle different types of builders
/// (standard builders, shared part builders, library builders) with a unified API.
/// {@endtemplate}
abstract class BuilderEntry {
  /// {@template builder_entry.key}
  /// A unique identifier for this builder.
  ///
  /// Used for referring to this builder in configuration and dependency declarations.
  /// {@endtemplate}
  String get key;

  /// {@template builder_entry.generate_to_cache}
  /// Whether outputs should be generated to a cache directory.
  ///
  /// When true, outputs are written to the build cache instead of modifying source files.
  /// When false, outputs are written directly to the source tree.
  /// {@endtemplate}
  bool get generateToCache;

  /// {@template builder_entry.generate_for}
  /// A set of glob patterns that determine which files this builder should process.
  ///
  /// The builder will only process files that match at least one of these patterns.
  /// If empty, the builder's [shouldBuildFor] method alone determines which files to process.
  /// {@endtemplate}
  Set<String> get generateFor;

  /// {@template builder_entry.applies}
  /// A set of builder keys that this builder applies to.
  ///
  /// This is used to define builder ordering. Any builder listed here
  /// will have this builder's outputs applied as inputs.
  /// {@endtemplate}
  Set<String> get applies;

  /// {@template builder_entry.runs_before}
  /// A set of builder keys that this builder should run before.
  ///
  /// This is used to define the phases of the build process. Builders in
  /// a later phase will not start until all builders that should run
  /// before them have completed.
  /// {@endtemplate}
  Set<String> get runsBefore;

  /// {@template builder_entry.output_extensions}
  /// The file extensions this builder will generate.
  ///
  /// Each extension should start with a dot (e.g., '.g.dart').
  /// {@endtemplate}
  Set<String> get outputExtensions;

  /// {@template builder_entry.should_generate_for}
  /// Determines whether this builder should generate output for the given candidate.
  ///
  /// This method combines the [generateFor] patterns with the builder's own
  /// [shouldBuildFor] logic to determine if the builder should process the file.
  ///
  /// [candidate] The build candidate to check.
  ///
  /// Returns true if this builder should process the candidate.
  /// {@endtemplate}
  bool shouldGenerateFor(BuildCandidate candidate);

  /// {@template builder_entry.on_prepare}
  /// Prepares the resolver for this builder.
  ///
  /// This method is called before any builds are executed to allow the builder
  /// to register any custom type annotations with the resolver.
  ///
  /// [resolver] The resolver to prepare.
  /// {@endtemplate}
  void onPrepare(ResolverImpl resolver);

  /// {@template builder_entry.build}
  /// Builds the given asset using this builder.
  ///
  /// This method executes the builder on the specified asset, using the provided
  /// resolver for type resolution and analysis.
  ///
  /// [resolver] The resolver to use for analysis.
  /// [asset] The asset to build.
  ///
  /// Returns a set of URIs representing the generated outputs.
  /// {@endtemplate}
  FutureOr<Set<Uri>> build(ResolverImpl resolver, Asset asset);

  /// {@template builder_entry.constructor}
  /// Creates a [BuilderEntry] with a standard builder.
  ///
  /// [key] A unique identifier for this builder.
  /// [builder] A factory function that creates the builder.
  /// [generateToCache] Whether outputs should be written to the build cache.
  /// [generateFor] Glob patterns that determine which files to process.
  /// [runsBefore] Builder keys that this builder should run before.
  /// [options] Configuration options for the builder.
  /// [annotationsTypeMap] Custom type annotations to register with the resolver.
  /// [applies] Builder keys that this builder applies to.
  /// {@endtemplate}
  factory BuilderEntry(
    String key,
    BuilderFactory builder, {
    bool generateToCache,
    Set<String> generateFor,
    Set<String> runsBefore,
    Map<String, dynamic> options,
    Map<Type, String> registeredTypes,
    Set<String> applies,
  }) = BuilderEntryImpl;

  /// {@template builder_entry.for_shared_part}
  /// Creates a [BuilderEntry] with a shared part builder.
  ///
  /// A shared part builder generates code into a single shared part file
  /// for a source file, with multiple generators contributing to the same output.
  ///
  /// [key] A unique identifier for this builder.
  /// [generator] A factory function that creates the generator.
  /// [generateToCache] Whether outputs should be written to the build cache.
  /// [generateFor] Glob patterns that determine which files to process.
  /// [runsBefore] Builder keys that this builder should run before.
  /// [options] Configuration options for the builder.
  /// [annotationsTypeMap] Custom type annotations to register with the resolver.
  /// [allowSyntaxErrors] Whether to generate code even if the source file has syntax errors.
  /// [applies] Builder keys that this builder applies to.
  /// {@endtemplate}
  factory BuilderEntry.forSharedPart(
    String key,
    GeneratorFactory generator, {
    bool generateToCache,
    Set<String> generateFor,
    Set<String> runsBefore,
    Map<String, dynamic> options,
    Map<Type, String> registeredTypes,
    bool allowSyntaxErrors,
    Set<String> applies,
  }) = BuilderEntryImpl.forSharedPart;

  /// {@template builder_entry.for_library}
  /// Creates a [BuilderEntry] with a library builder.
  ///
  /// A library builder generates code into a separate library file,
  /// rather than a part file.
  ///
  /// [key] A unique identifier for this builder.
  /// [generator] A factory function that creates the generator.
  /// [generateToCache] Whether outputs should be written to the build cache.
  /// [generateFor] Glob patterns that determine which files to process.
  /// [runsBefore] Builder keys that this builder should run before.
  /// [options] Configuration options for the builder.
  /// [annotationsTypeMap] Custom type annotations to register with the resolver.
  /// [allowSyntaxErrors] Whether to generate code even if the source file has syntax errors.
  /// [applies] Builder keys that this builder applies to.
  /// [outputExtensions] The file extensions this builder will generate.
  /// {@endtemplate}
  factory BuilderEntry.forLibrary(
    String key,
    GeneratorFactory generator, {
    bool generateToCache,
    Set<String> generateFor,
    Set<String> runsBefore,
    Map<String, dynamic> options,
    Map<Type, String> typeRegisterMap,
    bool allowSyntaxErrors,
    Set<String> applies,
    required Set<String> outputExtensions,
  }) = BuilderEntryImpl.forLibrary;
}

/// {@template builder_entry_impl}
/// An implementation of [BuilderEntry] that wraps a standard builder.
///
/// This class handles the configuration and execution of a single builder,
/// providing methods to determine which files to process and how to build them.
/// {@endtemplate}
class BuilderEntryImpl implements BuilderEntry {
  /// {@macro builder_entry.key}
  @override
  final String key;

  /// The wrapped builder that performs the actual code generation
  final Builder builder;

  /// {@macro builder_entry.generate_to_cache}
  @override
  final bool generateToCache;

  /// {@macro builder_entry.generate_for}
  @override
  final Set<String> generateFor;

  /// {@macro builder_entry.runs_before}
  @override
  final Set<String> runsBefore;

  /// {@macro builder_entry.applies}
  @override
  final Set<String> applies;

  /// A map from annotation types to their string representations
  final Map<Type, String> registeredTypes;

  /// {@template builder_entry_impl.constructor}
  /// Creates a [BuilderEntryImpl] with a standard builder.
  ///
  /// [key] A unique identifier for this builder.
  /// [builder] A factory function that creates the builder.
  /// [generateToCache] Whether outputs should be written to the build cache.
  /// [generateFor] Glob patterns that determine which files to process.
  /// [runsBefore] Builder keys that this builder should run before.
  /// [registeredTypes] Custom type annotations to register with the resolver.
  /// [applies] Builder keys that this builder applies to.
  /// [options] Configuration options for the builder.
  /// {@endtemplate}
  BuilderEntryImpl(
    this.key,
    BuilderFactory builder, {
    this.generateToCache = false,
    this.generateFor = const <String>{},
    Set<String> runsBefore = const <String>{},
    this.registeredTypes = const <Type, String>{},
    this.applies = const <String>{},
    Map<String, dynamic> options = const <String, dynamic>{},
  }) : // must run before a builder to be able to apply it
       runsBefore = <String>{...runsBefore, ...applies},
       builder = builder(BuilderOptions(options));

  /// {@template builder_entry_impl.for_shared_part}
  /// Creates a [BuilderEntryImpl] with a shared part builder.
  ///
  /// [key] A unique identifier for this builder.
  /// [generator] A factory function that creates the generator.
  /// [generateToCache] Whether outputs should be written to the build cache.
  /// [generateFor] Glob patterns that determine which files to process.
  /// [runsBefore] Builder keys that this builder should run before.
  /// [options] Configuration options for the builder.
  /// [registeredTypes] Runtime type register map for the builder.
  /// [allowSyntaxErrors] Whether to generate code even if the source file has syntax errors.
  /// [applies] Builder keys that this builder applies to.
  /// {@endtemplate}
  factory BuilderEntryImpl.forSharedPart(
    String key,
    GeneratorFactory generator, {
    bool generateToCache = false,
    Set<String> generateFor = const <String>{},
    Set<String> runsBefore = const <String>{},
    Map<String, dynamic> options = const <String, dynamic>{},
    Map<Type, String> registeredTypes = const <Type, String>{},
    bool allowSyntaxErrors = false,
    Set<String> applies = const <String>{},
  }) {
    return BuilderEntryImpl(
      key,
      (BuilderOptions ops) =>
          SharedPartBuilder(<Generator>[generator(ops)], allowSyntaxErrors: allowSyntaxErrors, options: ops),
      generateToCache: generateToCache,
      generateFor: generateFor,
      runsBefore: <String>{...runsBefore, ...applies},
      options: options,
      registeredTypes: registeredTypes,
      applies: applies,
    );
  }

  /// {@template builder_entry_impl.for_library}
  /// Creates a [BuilderEntryImpl] with a library builder.
  ///
  /// [key] A unique identifier for this builder.
  /// [generator] A factory function that creates the generator.
  /// [generateToCache] Whether outputs should be written to the build cache.
  /// [generateFor] Glob patterns that determine which files to process.
  /// [runsBefore] Builder keys that this builder should run before.
  /// [applies] Builder keys that this builder applies to.
  /// [options] Configuration options for the builder.
  /// [typeRegisterMap] Runtime type register map for the builder.
  /// [allowSyntaxErrors] Whether to generate code even if the source file has syntax errors.
  /// [outputExtensions] The file extensions this builder will generate.
  /// {@endtemplate}
  factory BuilderEntryImpl.forLibrary(
    String key,
    GeneratorFactory generator, {
    bool generateToCache = false,
    Set<String> generateFor = const <String>{},
    Set<String> runsBefore = const <String>{},
    Set<String> applies = const <String>{},
    Map<String, dynamic> options = const <String, dynamic>{},
    Map<Type, String> typeRegisterMap = const <Type, String>{},
    bool allowSyntaxErrors = false,
    required Set<String> outputExtensions,
  }) {
    return BuilderEntryImpl(
      key,
      (BuilderOptions ops) => LibraryBuilder(
        generator(ops),
        allowSyntaxErrors: allowSyntaxErrors,
        outputExtensions: outputExtensions,
        options: ops,
      ),
      generateToCache: generateToCache,
      generateFor: generateFor,
      runsBefore: <String>{...runsBefore, ...applies},
      applies: applies,
      options: options,
      registeredTypes: typeRegisterMap,
    );
  }

  /// {@macro builder_entry.should_generate_for}
  @override
  bool shouldGenerateFor(BuildCandidate candidate) {
    if (generateFor.isNotEmpty) {
      for (final String pattern in generateFor) {
        final Glob glob = Glob(pattern);
        if (glob.matches(candidate.asset.uri.path)) {
          return builder.shouldBuildFor(candidate);
        }
      }
      return false;
    }
    return builder.shouldBuildFor(candidate);
  }

  /// {@macro builder_entry.on_prepare}
  @override
  void onPrepare(ResolverImpl resolver) {
    resolver.registerTypesMap(registeredTypes);
  }

  /// {@macro builder_entry.build}
  @override
  FutureOr<Set<Uri>> build(ResolverImpl resolver, Asset asset) async {
    final BuildStepImpl buildStep = BuildStepImpl(
      asset,
      resolver,
      allowedExtensions: builder.outputExtensions,
      generateToCache: generateToCache,
    );
    await builder.build(buildStep);
    return buildStep.outputs;
  }

  @override
  String toString() => key;

  /// {@macro builder_entry.output_extensions}
  @override
  Set<String> get outputExtensions => builder.outputExtensions;
}

/// {@template combining_builder_entry}
/// A [BuilderEntry] that combines multiple builders into a single logical unit.
///
/// This class is primarily used for combining multiple [SharedPartBuilder]s
/// that generate code to the same part file. It allows them to be coordinated
/// and run as a single builder entry, improving build efficiency.
/// {@endtemplate}
class CombiningBuilderEntry implements BuilderEntry {
  /// The list of builders to combine
  final List<Builder> builders;

  /// {@macro builder_entry.key}
  @override
  final String key;

  /// A map from annotation types to their string representations
  final Map<Type, String> annotationsTypeMap;

  /// {@template combining_builder_entry.constructor}
  /// Creates a [CombiningBuilderEntry] that combines multiple builders.
  ///
  /// [builders] The list of builders to combine.
  /// [key] A unique identifier for this combined builder.
  /// [generateFor] Glob patterns that determine which files to process.
  /// [runsBefore] Builder keys that this combined builder should run before.
  /// [applies] Builder keys that this combined builder applies to.
  /// [annotationsTypeMap] Custom type annotations to register with the resolver.
  /// {@endtemplate}
  CombiningBuilderEntry({
    required this.builders,
    required this.key,
    required this.generateFor,
    required this.runsBefore,
    this.applies = const <String>{},
    this.annotationsTypeMap = const <Type, String>{},
  });

  /// {@macro builder_entry.generate_to_cache}
  ///
  /// Always returns false for combined builders, as they cannot generate to cache.
  @override
  bool get generateToCache => false;

  /// {@macro builder_entry.generate_for}
  @override
  final Set<String> generateFor;

  /// {@macro builder_entry.runs_before}
  @override
  final Set<String> runsBefore;

  /// {@macro builder_entry.applies}
  @override
  final Set<String> applies;

  /// {@macro builder_entry.should_generate_for}
  @override
  bool shouldGenerateFor(BuildCandidate candidate) {
    if (generateFor.isNotEmpty) {
      for (final String pattern in generateFor) {
        final Glob glob = Glob(pattern);
        if (glob.matches(candidate.asset.uri.path)) {
          for (final Builder builder in builders) {
            if (builder.shouldBuildFor(candidate)) {
              return true;
            }
          }
        }
        return false;
      }
    }
    for (final Builder builder in builders) {
      if (builder.shouldBuildFor(candidate)) {
        return true;
      }
    }
    return false;
  }

  /// {@macro builder_entry.on_prepare}
  @override
  void onPrepare(ResolverImpl resolver) {
    resolver.registerTypesMap(annotationsTypeMap);
  }

  /// {@macro builder_entry.build}
  @override
  FutureOr<Set<Uri>> build(ResolverImpl resolver, Asset asset) async {
    final Uri outputUri = asset.uriWithExtension(SharedPartBuilder.extension);
    final SharedBuildStep buildStep = SharedBuildStep(asset, resolver, outputUri: outputUri);
    for (final Builder builder in builders) {
      await builder.build(buildStep);
    }
    await buildStep.flush();
    return buildStep.outputs;
  }

  /// {@template combining_builder_entry.from_entries}
  /// Creates a [CombiningBuilderEntry] from a list of [BuilderEntryImpl]s.
  ///
  /// This factory method combines multiple builder entries into a single
  /// combined entry, merging their configuration and builders.
  ///
  /// [entries] The list of builder entries to combine.
  ///
  /// Returns a new [CombiningBuilderEntry] that combines the given entries.
  /// {@endtemplate}
  static CombiningBuilderEntry fromEntries(List<BuilderEntryImpl> entries) {
    final String key = entries.map((BuilderEntryImpl e) => e.key).join('|');
    final List<Builder> builders = entries.map((BuilderEntryImpl e) => e.builder).toList();
    final Map<Type, String> annotationsTypeMap = <Type, String>{
      for (final BuilderEntryImpl entry in entries) ...entry.registeredTypes,
    };

    return CombiningBuilderEntry(
      builders: builders,
      key: key,
      generateFor: entries.expand((BuilderEntryImpl e) => e.generateFor).toSet(),
      runsBefore: entries.expand((BuilderEntryImpl e) => e.runsBefore).toSet(),
      annotationsTypeMap: annotationsTypeMap,
      applies: entries.expand((BuilderEntryImpl e) => e.applies).toSet(),
    );
  }

  @override
  String toString() => key;

  /// {@macro builder_entry.output_extensions}
  @override
  late final Set<String> outputExtensions = Set<String>.of(builders.expand((Builder e) => e.outputExtensions));
}
