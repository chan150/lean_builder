import 'package:collection/collection.dart' show SetEquality, MapEquality, ListEquality;

/// Represents a runtime type entry used for registering type annotations.
///
/// This class stores information about a type that needs to be registered
/// at runtime, including its name, optional import path, and source identifier.
class RuntimeTypeRegisterEntry {
  /// The name of the type to be registered.
  final String name;

  /// Optional import path for the type, may be null if the type is from the same library.
  final String? import;

  /// Source identifier where this type is defined or referenced.
  final String srcId;

  /// Creates a new runtime type register entry.
  ///
  /// @param name The name of the type
  /// @param import The import path (can be null)
  /// @param srcId The source identifier
  RuntimeTypeRegisterEntry(this.name, this.import, this.srcId);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RuntimeTypeRegisterEntry &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          import == other.import &&
          srcId == other.srcId;

  @override
  int get hashCode => name.hashCode ^ import.hashCode ^ srcId.hashCode;

  @override
  String toString() {
    return 'RuntimeTypeRegisterEntry{name: $name, import: $import, srcId: $srcId}';
  }
}

/// Defines a builder configuration for code generation.
///
/// This class contains all the information needed to instantiate and configure
/// a builder during the build process, including its type, inputs, outputs,
/// and various configuration options.
class BuilderDefinitionEntry {
  /// Unique identifier for this builder.
  final String key;

  /// Import path for the builder class.
  final String import;

  /// Name of the generator class to instantiate.
  final String generatorName;

  /// Whether the output should be cached.
  final bool? generateToCache;

  /// Builder keys that should run before this builder.
  final Set<String>? runsBefore;

  /// Glob patterns specifying which files this builder should process.
  final Set<String>? generateFor;

  /// Builder keys that this builder applies to (for post-process builders).
  final Set<String>? applies;

  /// Additional configuration options for this builder.
  final Map<String, dynamic>? options;

  /// The type of builder (shared, library, or custom).
  final BuilderType builderType;

  /// Whether to continue processing even when syntax errors are present.
  final bool? allowSyntaxErrors;

  /// Type annotations this builder processes.
  final List<RuntimeTypeRegisterEntry>? registeredTypes;

  /// Whether this builder expects options to be provided.
  final bool expectsOptions;

  /// File extensions this builder will produce.
  final Set<String>? outputExtensions;

  /// Creates a new builder definition entry with the specified parameters.
  BuilderDefinitionEntry({
    required this.key,
    required this.import,
    required this.builderType,
    required this.generatorName,
    required this.expectsOptions,
    this.applies,
    this.options,
    this.generateToCache,
    this.generateFor,
    this.runsBefore,
    this.registeredTypes,
    this.allowSyntaxErrors,
    this.outputExtensions,
  });

  /// Merges this builder definition with an override.
  ///
  /// Creates a new builder definition that incorporates the overridden
  /// values from the provided [override] object. Non-null values in the
  /// override take precedence over values in this definition.
  ///
  /// @param override The builder override to apply
  /// @return A new builder definition with merged values
  BuilderDefinitionEntry merge(BuilderOverride override) {
    final Map<String, dynamic> mergedOptions = options ?? <String, dynamic>{};
    if (override.options != null) {
      mergedOptions.addAll(override.options!);
    }
    return BuilderDefinitionEntry(
      key: key,
      import: import,
      generatorName: generatorName,
      generateToCache: generateToCache,
      options: mergedOptions.isEmpty ? null : mergedOptions,
      generateFor: override.generateFor ?? generateFor,
      runsBefore: override.runsBefore ?? runsBefore,
      builderType: builderType,
      expectsOptions: expectsOptions,
      registeredTypes: registeredTypes,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BuilderDefinitionEntry &&
          runtimeType == other.runtimeType &&
          key == other.key &&
          import == other.import &&
          generatorName == other.generatorName &&
          generateToCache == other.generateToCache &&
          builderType == other.builderType &&
          allowSyntaxErrors == other.allowSyntaxErrors &&
          const SetEquality<String>().equals(runsBefore, other.runsBefore) &&
          const SetEquality<String>().equals(generateFor, other.generateFor) &&
          const SetEquality<String>().equals(outputExtensions, other.outputExtensions) &&
          const ListEquality<RuntimeTypeRegisterEntry>().equals(registeredTypes, other.registeredTypes) &&
          const MapEquality<String, dynamic>().equals(options, other.options);

  @override
  int get hashCode =>
      import.hashCode ^
      generatorName.hashCode ^
      generateToCache.hashCode ^
      builderType.hashCode ^
      allowSyntaxErrors.hashCode ^
      const ListEquality<RuntimeTypeRegisterEntry>().hash(registeredTypes) ^
      const SetEquality<String>().hash(outputExtensions) ^
      const SetEquality<String>().hash(generateFor) ^
      const SetEquality<String>().hash(runsBefore) ^
      const MapEquality<String, dynamic>().hash(options);

  @override
  String toString() {
    return 'BuilderDefinitionEntry{key: $key, import: $import, generatorName: $generatorName, generateToCache: $generateToCache, runsBefore: $runsBefore, generateFor: $generateFor, options: $options, builderType: $builderType, allowSyntaxErrors: $allowSyntaxErrors, annotationsTypeMap: $registeredTypes, expectsOptions: $expectsOptions, outputExtensions: $outputExtensions}';
  }
}

/// Represents overrides for a builder configuration.
///
/// These overrides allow customizing a builder's behavior without
/// modifying its original definition. Typically used in build configuration
/// files to adjust builder settings for specific projects.
final class BuilderOverride {
  /// The key of the builder to override.
  final String key;

  /// Override for which files the builder should process.
  final Set<String>? generateFor;

  /// Override for configuration options.
  final Map<String, dynamic>? options;

  /// Override for builders that should run before this one.
  final Set<String>? runsBefore;

  /// Creates a new builder override with the specified parameters.
  ///
  /// @param key The key of the builder to override
  /// @param options Optional configuration options to override
  /// @param generateFor Optional file patterns to override
  /// @param runsBefore Optional dependencies to override
  const BuilderOverride({required this.key, this.options, this.generateFor, this.runsBefore});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BuilderOverride &&
          runtimeType == other.runtimeType &&
          const SetEquality<String>().equals(generateFor, other.generateFor) &&
          const SetEquality<String>().equals(runsBefore, other.runsBefore) &&
          const MapEquality<String, dynamic>().equals(options, other.options);

  @override
  int get hashCode =>
      const SetEquality<String>().hash(generateFor) ^
      const MapEquality<String, dynamic>().hash(options) ^
      const SetEquality<String>().hash(runsBefore);

  @override
  String toString() {
    return 'BuilderOverride{key: $key, generateFor: $generateFor, options: $options, runsBefore: $runsBefore}';
  }
}

/// Enumerates the different types of builders supported by the system.
enum BuilderType {
  /// A shared builder that doesn't generate new files but provides functionality to other builders.
  shared,

  /// A library builder that generates files used by the library itself.
  library,

  /// A custom builder with project-specific functionality.
  custom;

  /// Whether this builder is a shared builder.
  bool get isShared => this == BuilderType.shared;

  /// Whether this builder is a library builder.
  bool get isLibrary => this == BuilderType.library;

  /// Whether this builder is a custom builder.
  bool get isCustom => this == BuilderType.custom;
}
