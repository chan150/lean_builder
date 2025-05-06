import 'package:collection/collection.dart';

class RuntimeTypeRegisterEntry {
  final String name;
  final String? import;
  final String srcId;

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

class BuilderDefinitionEntry {
  final String key;
  final String import;
  final String generatorName;
  final bool? generateToCache;
  final Set<String>? runsBefore;
  final Set<String>? generateFor;
  final Set<String>? applies;
  final Map<String, dynamic>? options;
  final BuilderType builderType;
  final bool? allowSyntaxErrors;
  final List<RuntimeTypeRegisterEntry>? annotationsTypeMap;
  final bool expectsOptions;
  final Set<String>? outputExtensions;

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
          key == other.key &&
          import == other.import &&
          generatorName == other.generatorName &&
          generateToCache == other.generateToCache &&
          builderType == other.builderType &&
          allowSyntaxErrors == other.allowSyntaxErrors &&
          const SetEquality().equals(runsBefore, other.runsBefore) &&
          const SetEquality().equals(generateFor, other.generateFor) &&
          const SetEquality().equals(outputExtensions, other.outputExtensions) &&
          const ListEquality().equals(annotationsTypeMap, other.annotationsTypeMap) &&
          const MapEquality().equals(options, other.options);

  @override
  int get hashCode =>
      import.hashCode ^
      generatorName.hashCode ^
      generateToCache.hashCode ^
      builderType.hashCode ^
      allowSyntaxErrors.hashCode ^
      const ListEquality().hash(annotationsTypeMap) ^
      const SetEquality().hash(outputExtensions) ^
      const SetEquality().hash(generateFor) ^
      const SetEquality().hash(runsBefore) ^
      const MapEquality().hash(options);

  @override
  String toString() {
    return 'BuilderDefinitionEntry{key: $key, import: $import, generatorName: $generatorName, generateToCache: $generateToCache, runsBefore: $runsBefore, generateFor: $generateFor, options: $options, builderType: $builderType, allowSyntaxErrors: $allowSyntaxErrors, annotationsTypeMap: $annotationsTypeMap, expectsOptions: $expectsOptions, outputExtensions: $outputExtensions}';
  }
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

  @override
  String toString() {
    return 'BuilderOverride{key: $key, generateFor: $generateFor, options: $options, runsBefore: $runsBefore}';
  }
}

enum BuilderType {
  shared,
  library,
  custom;

  bool get isShared => this == BuilderType.shared;

  bool get isLibrary => this == BuilderType.library;

  bool get isCustom => this == BuilderType.custom;
}
