import 'package:collection/collection.dart';

abstract class ParsedBuilderEntry {
  final String key;
  final String package;

  const ParsedBuilderEntry({required this.key, required this.package});
}

class BuilderDefinitionEntry extends ParsedBuilderEntry {
  final String import;
  final String builderFactory;
  final bool generateToCache;
  final Set<String>? runsBefore;
  final Set<String>? generateFor;
  final Map<String, dynamic>? options;

  BuilderDefinitionEntry({
    required super.key,
    required super.package,
    required this.options,
    required this.import,
    required this.builderFactory,
    required this.generateToCache,
    required this.generateFor,
    required this.runsBefore,
  });

  BuilderDefinitionEntry merge(BuilderOverrideEntry override) {
    final mergedOptions = options ?? {};
    if (override.options != null) {
      mergedOptions.addAll(override.options!);
    }
    return BuilderDefinitionEntry(
      key: key,
      package: package,
      import: import,
      builderFactory: builderFactory,
      generateToCache: generateToCache,
      options: mergedOptions.isEmpty ? null : mergedOptions,
      generateFor: override.generateFor ?? generateFor,
      runsBefore: override.runsBefore ?? runsBefore,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BuilderDefinitionEntry &&
          runtimeType == other.runtimeType &&
          import == other.import &&
          builderFactory == other.builderFactory &&
          generateToCache == other.generateToCache &&
          const SetEquality().equals(runsBefore, other.runsBefore) &&
          const SetEquality().equals(generateFor, other.generateFor) &&
          const MapEquality().equals(options, other.options);

  @override
  int get hashCode =>
      import.hashCode ^
      builderFactory.hashCode ^
      generateToCache.hashCode ^
      const SetEquality().hash(generateFor) ^
      const SetEquality().hash(runsBefore) ^
      const MapEquality().hash(options);
}

class BuilderOverrideEntry extends ParsedBuilderEntry {
  final Set<String>? generateFor;
  final Map<String, dynamic>? options;
  final Set<String>? runsBefore;

  BuilderOverrideEntry({
    required super.key,
    required super.package,
    required this.options,
    required this.generateFor,
    required this.runsBefore,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BuilderOverrideEntry &&
          runtimeType == other.runtimeType &&
          const SetEquality().equals(generateFor, other.generateFor) &&
          const SetEquality().equals(runsBefore, other.runsBefore) &&
          const MapEquality().equals(options, other.options);

  @override
  int get hashCode =>
      const SetEquality().hash(generateFor) ^ const MapEquality().hash(options) ^ const SetEquality().hash(runsBefore);
}
