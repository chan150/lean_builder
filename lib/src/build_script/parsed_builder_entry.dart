import 'package:collection/collection.dart';

class RuntimeTypeRegisterEntry {
  final String name;
  final String? import;
  final String srcId;

  RuntimeTypeRegisterEntry(this.name, this.import, this.srcId);
}

class BuilderDefinitionEntry {
  final String key;
  final String import;
  final String generatorName;
  final bool? generateToCache;
  final Set<String>? runsBefore;
  final Set<String>? generateFor;
  final Map<String, dynamic>? options;
  final BuilderType builderType;
  final bool? allowSyntaxErrors;
  final List<RuntimeTypeRegisterEntry>? annotationsTypeMap;
  final bool expectsOptions;
  final Set<String>? outputExtensions;

  BuilderDefinitionEntry({
    required this.key,
    required this.options,
    required this.import,
    required this.generatorName,
    required this.generateToCache,
    required this.generateFor,
    required this.runsBefore,
    required this.builderType,
    required this.expectsOptions,
    this.annotationsTypeMap,
    this.allowSyntaxErrors,
    this.outputExtensions,
  });

  BuilderDefinitionEntry merge(BuilderOverride override) {
    final mergedOptions = options ?? {};
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
      annotationsTypeMap: annotationsTypeMap,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BuilderDefinitionEntry &&
          runtimeType == other.runtimeType &&
          import == other.import &&
          generatorName == other.generatorName &&
          generateToCache == other.generateToCache &&
          const SetEquality().equals(runsBefore, other.runsBefore) &&
          const SetEquality().equals(generateFor, other.generateFor) &&
          const MapEquality().equals(options, other.options);

  @override
  int get hashCode =>
      import.hashCode ^
      generatorName.hashCode ^
      generateToCache.hashCode ^
      const SetEquality().hash(generateFor) ^
      const SetEquality().hash(runsBefore) ^
      const MapEquality().hash(options);
}

final class BuilderOverride {
  final String key;
  final Set<String>? generateFor;
  final Map<String, dynamic>? options;
  final Set<String>? runsBefore;

  const BuilderOverride({required this.key, this.options, this.generateFor, this.runsBefore});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BuilderOverride &&
          runtimeType == other.runtimeType &&
          const SetEquality().equals(generateFor, other.generateFor) &&
          const SetEquality().equals(runsBefore, other.runsBefore) &&
          const MapEquality().equals(options, other.options);

  @override
  int get hashCode =>
      const SetEquality().hash(generateFor) ^ const MapEquality().hash(options) ^ const SetEquality().hash(runsBefore);
}

enum BuilderType {
  shared,
  library,
  custom;

  bool get isShared => this == BuilderType.shared;

  bool get isLibrary => this == BuilderType.library;

  bool get isCustom => this == BuilderType.custom;
}
