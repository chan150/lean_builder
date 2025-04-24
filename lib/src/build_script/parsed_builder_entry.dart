import 'package:collection/collection.dart';

abstract class ParsedBuilderEntry {
  final String key;
  final String package;

  const ParsedBuilderEntry({required this.key, required this.package});
}

class BuilderDefinitionEntry extends ParsedBuilderEntry {
  final String import;
  final String builderFactory;
  final bool hideOutput;
  final Set<String>? generateFor;
  final Map<String, dynamic>? options;

  BuilderDefinitionEntry({
    required super.key,
    required super.package,
    required this.options,
    required this.import,
    required this.builderFactory,
    required this.hideOutput,
    required this.generateFor,
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
      hideOutput: hideOutput,
      options: mergedOptions.isEmpty ? null : mergedOptions,
      generateFor: override.generateFor ?? generateFor,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BuilderDefinitionEntry &&
          runtimeType == other.runtimeType &&
          import == other.import &&
          builderFactory == other.builderFactory &&
          hideOutput == other.hideOutput &&
          const SetEquality().equals(generateFor, other.generateFor) &&
          const MapEquality().equals(options, other.options);

  @override
  int get hashCode =>
      import.hashCode ^
      builderFactory.hashCode ^
      hideOutput.hashCode ^
      const SetEquality().hash(generateFor) ^
      const MapEquality().hash(options);
}

class BuilderOverrideEntry extends ParsedBuilderEntry {
  final Set<String>? generateFor;
  final Map<String, dynamic>? options;

  BuilderOverrideEntry({required super.key, required super.package, required this.options, required this.generateFor});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BuilderOverrideEntry &&
          runtimeType == other.runtimeType &&
          const SetEquality().equals(generateFor, other.generateFor) &&
          const MapEquality().equals(options, other.options);

  @override
  int get hashCode => const SetEquality().hash(generateFor) ^ const MapEquality().hash(options);
}
