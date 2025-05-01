import 'dart:async';

import 'package:lean_builder/builder.dart';
import 'package:glob/glob.dart';
import 'package:lean_builder/src/asset/asset.dart';

abstract class BuilderEntry {
  String get key;

  bool get generateToCache;

  Set<String> get generateFor;

  Set<String> get runsBefore;

  bool shouldGenerateFor(BuildCandidate candidate);

  FutureOr<Set<Uri>> build(Resolver resolver, Asset asset);

  factory BuilderEntry(
    String key,
    BuilderFactory builderFactory, {
    bool generateToCache,
    Set<String> generateFor,
    Set<String> runsBefore,
    Map<String, dynamic> options,
  }) = BuilderEntryImpl;
}

class BuilderEntryImpl implements BuilderEntry {
  @override
  final String key;

  final BuilderFactory builderFactory;

  @override
  final bool generateToCache;

  @override
  final Set<String> generateFor;

  final BuilderOptions options;

  @override
  final Set<String> runsBefore;

  BuilderEntryImpl(
    this.key,
    this.builderFactory, {
    this.generateToCache = false,
    this.generateFor = const {},
    this.runsBefore = const {},
    Map<String, dynamic> options = const {},
  }) : options = BuilderOptions(options);

  Builder? _builder;

  Builder get builder {
    return _builder ??= builderFactory(options);
  }

  @override
  bool shouldGenerateFor(BuildCandidate candidate) {
    if (generateFor.isNotEmpty) {
      for (final pattern in generateFor) {
        final glob = Glob(pattern);
        if (glob.matches(candidate.asset.uri.path)) {
          return builder.shouldBuild(candidate);
        }
      }
      return false;
    }
    return builder.shouldBuild(candidate);
  }

  @override
  FutureOr<Set<Uri>> build(Resolver resolver, Asset asset) async {
    final buildStep = BuildStepImpl(asset, resolver, allowedExtensions: builder.allowedExtensions);
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

  CombiningBuilderEntry({
    required this.builders,
    required this.key,
    required this.generateFor,
    required this.runsBefore,
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
            if (builder.shouldBuild(candidate)) {
              return true;
            }
          }
        }
        return false;
      }
    }
    for (final builder in builders) {
      if (builder.shouldBuild(candidate)) {
        return true;
      }
    }
    return false;
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
    return CombiningBuilderEntry(
      builders: builders,
      key: key,
      generateFor: entries.expand((e) => e.generateFor).toSet(),
      runsBefore: entries.expand((e) => e.runsBefore).toSet(),
    );
  }

  @override
  String toString() => key;
}
