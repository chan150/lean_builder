import 'dart:async';

import 'package:lean_builder/builder.dart';
import 'package:glob/glob.dart';
import 'package:lean_builder/src/asset/asset.dart';
import 'package:lean_builder/src/resolvers/resolver.dart' show ResolverImpl;

/// Creates a [Generator] with the given [options].
typedef GeneratorFactory = Generator Function(BuilderOptions options);

/// Creates a [Builder] honoring the configuration in [options].
typedef BuilderFactory = Builder Function(BuilderOptions options);

abstract class BuilderEntry {
  String get key;

  bool get generateToCache;

  Set<String> get generateFor;

  Set<String> get applies;

  Set<String> get runsBefore;

  Set<String> get outputExtensions;

  bool shouldGenerateFor(BuildCandidate candidate);

  void onPrepare(ResolverImpl resolver);

  FutureOr<Set<Uri>> build(ResolverImpl resolver, Asset asset);

  factory BuilderEntry(
    String key,
    BuilderFactory builder, {
    bool generateToCache,
    Set<String> generateFor,
    Set<String> runsBefore,
    Map<String, dynamic> options,
    Map<Type, String> annotationsTypeMap,
    Set<String> applies,
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
    Set<String> applies,
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
    Set<String> applies,
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

  @override
  final Set<String> applies;

  final Map<Type, String> annotationsTypeMap;

  BuilderEntryImpl(
    this.key,
    BuilderFactory builder, {
    this.generateToCache = false,
    this.generateFor = const {},
    Set<String> runsBefore = const {},
    this.annotationsTypeMap = const {},
    this.applies = const {},
    Map<String, dynamic> options = const {},
  }) : // must run before a builder to be able to apply it
       runsBefore = {...runsBefore, ...applies},
       builder = builder(BuilderOptions(options));

  factory BuilderEntryImpl.forSharedPart(
    String key,
    GeneratorFactory generator, {
    bool generateToCache = false,
    Set<String> generateFor = const {},
    Set<String> runsBefore = const {},
    Map<String, dynamic> options = const {},
    Map<Type, String> annotationsTypeMap = const {},
    bool allowSyntaxErrors = false,
    Set<String> applies = const {},
  }) {
    return BuilderEntryImpl(
      key,
      (ops) => SharedPartBuilder([generator(ops)], allowSyntaxErrors: allowSyntaxErrors, options: ops),
      generateToCache: generateToCache,
      generateFor: generateFor,
      runsBefore: {...runsBefore, ...applies},
      options: options,
      annotationsTypeMap: annotationsTypeMap,
      applies: applies,
    );
  }

  factory BuilderEntryImpl.forLibrary(
    String key,
    GeneratorFactory generator, {
    bool generateToCache = false,
    Set<String> generateFor = const {},
    Set<String> runsBefore = const {},
    Set<String> applies = const {},
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
      runsBefore: {...runsBefore, ...applies},
      applies: applies,
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
  void onPrepare(ResolverImpl resolver) {
    resolver.registerTypesMap(annotationsTypeMap);
  }

  @override
  FutureOr<Set<Uri>> build(ResolverImpl resolver, Asset asset) async {
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

  @override
  Set<String> get outputExtensions => builder.outputExtensions;
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
    this.applies = const {},
    this.annotationsTypeMap = const {},
  });

  @override
  bool get generateToCache => false;

  @override
  final Set<String> generateFor;

  @override
  final Set<String> runsBefore;

  @override
  final Set<String> applies;

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
  void onPrepare(ResolverImpl resolver) {
    resolver.registerTypesMap(annotationsTypeMap);
  }

  @override
  FutureOr<Set<Uri>> build(ResolverImpl resolver, Asset asset) async {
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
      applies: entries.expand((e) => e.applies).toSet(),
    );
  }

  @override
  String toString() => key;

  @override
  Set<String> get outputExtensions => Set.of(builders.expand((e) => e.outputExtensions));
}
