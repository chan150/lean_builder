import 'dart:async';

import 'package:lean_builder/src/asset/asset.dart';
import 'package:lean_builder/src/graph/scan_results.dart';
import 'package:path/path.dart' as p;

import 'build_step.dart';

/// most of the code here is borrowed from the build package

/// The basic builder class, used to build new files from existing ones.
abstract class Builder {
  /// This is used to determine if the builder should be run for a given
  /// [BuildCandidate].
  bool shouldBuildFor(BuildCandidate candidate);

  /// Generates the outputs for a given [BuildStep].
  FutureOr<void> build(BuildStep buildStep);

  /// The allowed output extensions for this builder.
  ///
  /// the first element is the primary output extension, the rest are secondary
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

  @override
  String toString() {
    return 'BuilderOptions(config: $config)';
  }
}

class BuildCandidate {
  final Asset asset;

  /// this is always false if the asset is not a library (.dart)
  final bool hasTopLevelMetadata;

  /// this is always empty if the asset is not a library (.dart)
  final List<ExportedSymbol> exportedSymbols;

  BuildCandidate(this.asset, this.hasTopLevelMetadata, this.exportedSymbols);

  Uri get uri => asset.uri;

  String get path => uri.path;

  bool get isDartSource => extension == '.dart';

  String get extension => p.extension(path);
}

class ExportedSymbol {
  final String name;
  final SymbolType type;

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
