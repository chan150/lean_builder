import 'dart:async';

import 'package:lean_builder/src/asset/asset.dart';
import 'package:lean_builder/src/graph/scan_results.dart' show ReferenceType;
import 'package:path/path.dart' as p;

import 'build_step.dart';

/// {@template builder}
/// The basic builder class, used to build new files from existing ones.
///
/// Builders are responsible for generating output files from input files.
/// They declare which file extensions they can handle and produce, and
/// implement logic to transform inputs into outputs.
///
/// Subclasses must implement [build] to perform the actual code generation
/// and [shouldBuildFor] to determine if a file should be processed.
/// {@endtemplate}
abstract class Builder {
  /// {@template builder.should_build_for}
  /// This is used to determine if the builder should be run for a given
  /// [BuildCandidate].
  ///
  /// Implement this method to check if the candidate matches criteria for this
  /// builder, such as having top level metadata, specific type of elements (classes, enums ..etc), or matching file patterns.
  /// {@endtemplate}
  bool shouldBuildFor(BuildCandidate candidate);

  /// {@template builder.build}
  /// Generates the outputs for a given [BuildStep].
  ///
  /// This is where the actual code generation happens. Implementers should
  /// read the input asset from the build step, transform it as needed, and
  /// write one or more output files.
  /// {@endtemplate}
  FutureOr<void> build(BuildStep buildStep);

  /// {@template builder.output_extensions}
  /// The allowed output extensions for this builder.
  ///
  /// The first element is the primary output extension, the rest are secondary.
  /// Extensions should include the leading dot (e.g. '.g.dart').
  ///
  /// This set is used to validate that the builder only generates files
  /// with allowed extensions.
  /// {@endtemplate}
  Set<String> get outputExtensions;
}

/// {@template builder_options}
/// Configuration options for a Builder.
///
/// Provides a way to pass configuration to builders from the build script
/// or from builder overrides defined in build.yaml files.
/// {@endtemplate}
class BuilderOptions {
  /// A configuration with no options set.
  static const BuilderOptions empty = BuilderOptions(<String, dynamic>{});

  /// {@template builder_options.config}
  /// The configuration to apply to a given usage of a [Builder].
  ///
  /// A `Map` parsed from json or yaml. The value types will be `String`, `num`,
  /// `bool` or `List` or `Map` of these types.
  /// {@endtemplate}
  final Map<String, dynamic> config;

  /// {@template builder_options.constructor}
  /// Creates a new BuilderOptions with the given configuration.
  /// {@endtemplate}
  const BuilderOptions(this.config);

  /// {@template builder_options.override_with}
  /// Returns a new set of options with keys from [other] overriding options in
  /// this instance.
  ///
  /// Config values are overridden at a per-key granularity. There is no value
  /// level merging. [other] may be null, in which case this instance is
  /// returned directly.
  ///
  /// The `isRoot` value will also be overridden to value from [other].
  /// {@endtemplate}
  BuilderOptions overrideWith(BuilderOptions? other) {
    if (other == null) return this;
    return BuilderOptions(<String, dynamic>{...config, ...other.config});
  }

  @override
  String toString() {
    return 'BuilderOptions(config: $config)';
  }
}

/// {@template build_candidate}
/// Represents an asset that is a candidate for building.
///
/// Contains information about the asset and its content needed by builders
/// to determine if and how to process it.
/// {@endtemplate}
class BuildCandidate {
  /// {@template build_candidate.asset}
  /// The asset that may be processed by a builder.
  /// {@endtemplate}
  final Asset asset;

  /// {@template build_candidate.has_top_level_metadata}
  /// Whether the file has top-level metadata annotations.
  ///
  /// This is always false if the asset is not a Dart library.
  /// {@endtemplate}
  final bool hasTopLevelMetadata;

  /// {@template build_candidate.exported_symbols}
  /// The symbols exported by this asset.
  ///
  /// This is always empty if the asset is not a Dart library.
  /// {@endtemplate}
  final List<ExportedSymbol> exportedSymbols;

  /// {@template build_candidate.constructor}
  /// Creates a new build candidate with the specified asset and metadata.
  /// {@endtemplate}
  BuildCandidate(this.asset, this.hasTopLevelMetadata, this.exportedSymbols);

  /// {@macro build_candidate.asset}
  /// The URI of the asset.
  Uri get uri => asset.uri;

  /// The file path of the asset.
  String get path => uri.path;

  /// Whether this asset is a Dart source file.
  bool get isDartSource => extension == '.dart';

  /// The file extension of the asset (including the leading dot).
  String get extension => p.extension(path);

  /// Checks if the asset contains symbols of a specific type.
  bool _hasType(ReferenceType type) {
    return exportedSymbols.any((ExportedSymbol e) => e.type == type);
  }

  /// Whether the asset contains any class definitions.
  bool get hasClasses => _hasType(ReferenceType.$class);

  /// Whether the asset contains any function definitions.
  bool get hasFunctions => _hasType(ReferenceType.$function);

  /// Whether the asset contains any mixin definitions.
  bool get hasMixins => _hasType(ReferenceType.$mixin);

  /// Whether the asset contains any extension definitions.
  bool get hasExtensions => _hasType(ReferenceType.$extension);

  /// Whether the asset contains any enum definitions.
  bool get hasEnums => _hasType(ReferenceType.$enum);

  /// Whether the asset contains any top-level variable definitions.
  bool get hasTopLevelVariables => _hasType(ReferenceType.$variable);

  /// Whether the asset contains any top-level function definitions.
  bool get hasTopLevelFunctions => _hasType(ReferenceType.$function);
}

/// {@template exported_symbol}
/// Represents a symbol exported by an asset.
///
/// Contains the name and type of the symbol, which can be used by builders
/// to identify classes, enums, or other Dart elements in a file.
/// {@endtemplate}
class ExportedSymbol {
  /// {@template exported_symbol.name}
  /// The name of the exported symbol.
  /// {@endtemplate}
  final String name;

  /// {@template exported_symbol.type}
  /// The type of the exported symbol (class, enum, etc.).
  /// {@endtemplate}
  final ReferenceType type;

  /// {@template exported_symbol.constructor}
  /// Creates a new exported symbol with the specified name and type.
  /// {@endtemplate}
  ExportedSymbol(this.name, this.type);

  @override
  String toString() {
    return '$type $name';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ExportedSymbol && name == other.name && type == other.type;
  }

  @override
  int get hashCode {
    return name.hashCode ^ type.hashCode;
  }
}
