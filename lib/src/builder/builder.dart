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

  /// possible extensions for generated files
  ///
  /// The first extension is the primary output, and the rest are
  /// additional outputs.
  ///
  /// this can not be empty
  Set<String> get outputExtensions;
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
