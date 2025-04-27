import 'dart:async';

import 'package:lean_builder/src/asset/asset.dart';
import 'package:lean_builder/src/graph/scan_results.dart';

import 'build_step.dart';

/// most of the code here is borrowed from the build package

/// The basic builder class, used to build new files from existing ones.
abstract class Builder {
  /// This is used to determine if the builder should be run for a given
  /// [BuildCandidate].
  bool shouldBuild(BuildCandidate candidate);

  /// Generates the outputs for a given [BuildStep].
  FutureOr<void> build(BuildStep buildStep);

  /// Mapping from input file extension to output file extensions.
  ///
  /// All input sources matching any key in this map will be passed as build
  /// step to this builder. Only files with the same basename and an extension
  /// from the values in this map are expected as outputs.
  ///
  /// - If an empty key exists, all inputs are considered matching.
  /// - An instance of a builder must always return the same configuration.
  ///   Typically, a builder will return a `const` map.
  /// - Most builders will use a single input extension and one or more output
  ///   extensions.
  Map<String, Set<String>> get buildExtensions;

  Set<String> get allowedExtensions;
}

class BuilderOptions {
  /// A configuration with no options set.
  static const empty = BuilderOptions({});

  /// The configuration to apply to a given usage of a [Builder].
  ///
  /// A `Map` parsed from json or yaml. The value types will be `String`, `num`,
  /// `bool` or `List` or `Map` of these types.
  final Map<String, dynamic> config;

  const BuilderOptions(this.config);

  /// Returns a new set of options with keys from [other] overriding options in
  /// this instance.
  ///
  /// Config values are overridden at a per-key granularity. There is no value
  /// level merging. [other] may be null, in which case this instance is
  /// returned directly.
  ///
  /// The `isRoot` value will also be overridden to value from [other].
  BuilderOptions overrideWith(BuilderOptions? other) {
    // ignore: avoid_returning_this
    if (other == null) return this;
    return BuilderOptions(
      {}
        ..addAll(config)
        ..addAll(other.config),
    );
  }
}

/// Creates a [Builder] honoring the configuration in [options].
typedef BuilderFactory = Builder Function(BuilderOptions options);

class BuildCandidate {
  final Asset asset;
  final bool hasTopLevelMetadata;
  final List<ExportedSymbol> exportedSymbols;

  BuildCandidate(this.asset, this.hasTopLevelMetadata, this.exportedSymbols);

  Uri get uri => asset.uri;
  String get path => uri.path;
}

class ExportedSymbol {
  final String name;
  final TopLevelIdentifierType type;

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
