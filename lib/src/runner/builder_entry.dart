import 'dart:async';

import 'package:lean_builder/builder.dart';
import 'package:glob/glob.dart';
import 'package:lean_builder/src/asset/asset.dart';

/// Creates a [Generator] with the given [options].
typedef GeneratorFactory = Generator Function(BuilderOptions options);

/// Creates a [Builder] honoring the configuration in [options].
typedef BuilderFactory = Builder Function(BuilderOptions options);

abstract class BuilderEntry {
  String get key;

  bool get generateToCache;

  Set<String> get generateFor;

  Set<String> get runsBefore;

  bool shouldGenerateFor(BuildCandidate candidate);

  void onPrepare(Resolver resolver);

  FutureOr<Set<Uri>> build(Resolver resolver, Asset asset);

  factory BuilderEntry(
    String key,
    BuilderFactory builder, {
    bool generateToCache,
    Set<String> generateFor,
    Set<String> runsBefore,
    Map<String, dynamic> options,
    Map<Type, String> annotationsTypeMap,
  }) = BuilderEntryImpl;

  factory BuilderEntry.forSharedPart(
    String key,
    GeneratorFactory generator, {
    bool generateToCache,
    Set<String> generateFor,
    Set<String> runsBefore,
    Map<String, dynamic> options,
    Map<Type, String> annotationsTypeMap,
    bool allowSyntaxErrors,
  }) = BuilderEntryImpl.forSharedPart;

  factory BuilderEntry.forLibrary(
    String key,
    GeneratorFactory generator, {
    bool generateToCache,
    Set<String> generateFor,
    Set<String> runsBefore,
    Map<String, dynamic> options,
    Map<Type, String> annotationsTypeMap,
    bool allowSyntaxErrors,
    required Set<String> outputExtensions,
  }) = BuilderEntryImpl.forLibrary;
}

class BuilderEntryImpl implements BuilderEntry {
  @override
  final String key;

  final Builder builder;

  @override
  final bool generateToCache;

  @override
  final Set<String> generateFor;

  @override
  final Set<String> runsBefore;

  final Map<Type, String> annotationsTypeMap;

  BuilderEntryImpl(
    this.key,
    BuilderFactory builder, {
    this.generateToCache = false,
    this.generateFor = const {},
    this.runsBefore = const {},
    this.annotationsTypeMap = const {},
    Map<String, dynamic> options = const {},
  }) : builder = builder(BuilderOptions(options));

  factory BuilderEntryImpl.forSharedPart(
    String key,
    GeneratorFactory generator, {
    bool generateToCache = false,
    Set<String> generateFor = const {},
    Set<String> runsBefore = const {},
    Map<String, dynamic> options = const {},
    Map<Type, String> annotationsTypeMap = const {},
    bool allowSyntaxErrors = false,
  }) {
    return BuilderEntryImpl(
      key,
      (ops) => SharedPartBuilder([generator(ops)], allowSyntaxErrors: allowSyntaxErrors, options: ops),
      generateToCache: generateToCache,
      generateFor: generateFor,
      runsBefore: runsBefore,
      options: options,
      annotationsTypeMap: annotationsTypeMap,
    );
  }

  factory BuilderEntryImpl.forLibrary(
    String key,
    GeneratorFactory generator, {
    bool generateToCache = false,
    Set<String> generateFor = const {},
    Set<String> runsBefore = const {},
    Map<String, dynamic> options = const {},
    Map<Type, String> annotationsTypeMap = const {},
    bool allowSyntaxErrors = false,
    required Set<String> outputExtensions,
  }) {
    return BuilderEntryImpl(
      key,
      (ops) => LibraryBuilder(
        generator(ops),
        allowSyntaxErrors: allowSyntaxErrors,
        outputExtensions: outputExtensions,
        options: ops,
      ),
      generateToCache: generateToCache,
      generateFor: generateFor,
      runsBefore: runsBefore,
      options: options,
      annotationsTypeMap: annotationsTypeMap,
    );
  }

  @override
  bool shouldGenerateFor(BuildCandidate candidate) {
    if (generateFor.isNotEmpty) {
      for (final pattern in generateFor) {
        final glob = Glob(pattern);
        if (glob.matches(candidate.asset.uri.path)) {
          return builder.shouldBuildFor(candidate);
        }
      }
      return false;
    }
    return builder.shouldBuildFor(candidate);
  }

  @override
  void onPrepare(Resolver resolver) {
    resolver.registerTypesMap(annotationsTypeMap);
  }

  @override
  FutureOr<Set<Uri>> build(Resolver resolver, Asset asset) async {
    final buildStep = BuildStepImpl(
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
}

class CombiningBuilderEntry implements BuilderEntry {
  final List<Builder> builders;

  @override
  final String key;

  final Map<Type, String> annotationsTypeMap;

  CombiningBuilderEntry({
    required this.builders,
    required this.key,
    required this.generateFor,
    required this.runsBefore,
    this.annotationsTypeMap = const {},
  });

  @override
  bool get generateToCache => false;

  @override
  final Set<String> generateFor;

  @override
  final Set<String> runsBefore;

  @override
  bool shouldGenerateFor(BuildCandidate candidate) {
    if (generateFor.isNotEmpty) {
      for (final pattern in generateFor) {
        final glob = Glob(pattern);
        if (glob.matches(candidate.asset.uri.path)) {
          for (final builder in builders) {
            if (builder.shouldBuildFor(candidate)) {
              return true;
            }
          }
        }
        return false;
      }
    }
    for (final builder in builders) {
      if (builder.shouldBuildFor(candidate)) {
        return true;
      }
    }
    return false;
  }

  @override
  void onPrepare(Resolver resolver) {
    resolver.registerTypesMap(annotationsTypeMap);
  }

  @override
  FutureOr<Set<Uri>> build(Resolver resolver, Asset asset) async {
    final outputUri = asset.uriWithExtension(SharedPartBuilder.extension);
    final buildStep = SharedBuildStep(asset, resolver, outputUri: outputUri);
    for (final builder in builders) {
      await builder.build(buildStep);
    }
    await buildStep.flush();
    return buildStep.outputs;
  }

  static CombiningBuilderEntry fromEntries(List<BuilderEntryImpl> entries) {
    final key = entries.map((e) => e.key).join('|');
    final builders = entries.map((e) => e.builder).toList();
    final annotationsTypeMap = <Type, String>{for (final entry in entries) ...entry.annotationsTypeMap};

    return CombiningBuilderEntry(
      builders: builders,
      key: key,
      generateFor: entries.expand((e) => e.generateFor).toSet(),
      runsBefore: entries.expand((e) => e.runsBefore).toSet(),
      annotationsTypeMap: annotationsTypeMap,
    );
  }

  @override
  String toString() => key;
}
