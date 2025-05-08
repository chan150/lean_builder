import 'dart:io' show Platform;
import 'dart:math' as math show max, min;
import 'package:lean_builder/builder.dart';
import 'package:lean_builder/runner.dart';
import 'dart:collection' show HashMap;

import 'package:lean_builder/src/graph/references_scan_manager.dart';

/// {@template calculate_chunks}
/// Distributes a set of processable assets into chunks for parallel processing.
///
/// This function:
/// 1. Determines the optimal number of isolates based on available processors
/// 2. Splits assets into two groups: those with top-level metadata (TLM) and those without
/// 3. Distributes both groups evenly across the chunks to balance the workload
///
/// The approach ensures that:
/// - Each isolate gets roughly equal work
/// - Assets with annotations (which often require more processing) are evenly distributed
/// - All available CPU cores are efficiently utilized
///
/// [assets] The set of processable assets to distribute
///
/// Returns a list of sets, where each set contains the assets to be processed by one isolate
/// {@endtemplate}
List<Set<ProcessableAsset>> calculateChunks(Set<ProcessableAsset> assets) {
  final int isolateCount = math.max(1, Platform.numberOfProcessors - 1);
  final int actualIsolateCount = math.min(isolateCount, assets.length);

  final List<ProcessableAsset> assetsWithTLM =
      assets.where((ProcessableAsset a) => a.tlmFlag.hasNormal).toList();
  final List<ProcessableAsset> assetsWithoutTLM =
      assets.where((ProcessableAsset a) => !a.tlmFlag.hasNormal).toList();

  final List<Set<ProcessableAsset>> chunks =
      List<Set<ProcessableAsset>>.generate(
        actualIsolateCount,
        (_) => <ProcessableAsset>{},
      );

  // Distribute annotated assets evenly across chunks
  for (int i = 0; i < assetsWithTLM.length; i++) {
    chunks[i % actualIsolateCount].add(assetsWithTLM[i]);
  }

  // Distribute non-annotated assets evenly across chunks
  for (int i = 0; i < assetsWithoutTLM.length; i++) {
    chunks[i % actualIsolateCount].add(assetsWithoutTLM[i]);
  }
  //todo: maybe consider strongly connected components approach to distribute assets in the future
  return chunks;
}

/// {@template calculate_builder_phases}
/// Organizes builders into phases for sequential execution.
///
/// This function:
/// 1. Groups SharedPartBuilders into a combined entry for efficiency
/// 2. Orders builders based on their dependencies (runsBefore)
/// 3. Places builders into phases, where each phase contains builders that can run in parallel
///
/// A builder is placed in a new phase when a builder in the current phase
/// declares that it should run before that builder.
///
/// [entries] The list of builder entries to organize
///
/// Returns a list of phases, where each phase is a list of builders that can run in parallel
/// {@endtemplate}
List<List<BuilderEntry>> calculateBuilderPhases(List<BuilderEntry> entries) {
  final List<BuilderEntry> effectiveEntries = <BuilderEntry>[];
  final List<BuilderEntryImpl> sharedPartEntries = <BuilderEntryImpl>[];

  for (final BuilderEntry entry in entries) {
    if (entry is BuilderEntryImpl && entry.builder is SharedPartBuilder) {
      sharedPartEntries.add(entry);
    } else {
      effectiveEntries.add(entry);
    }
  }
  if (sharedPartEntries.isNotEmpty) {
    final CombiningBuilderEntry combiningEntry =
        CombiningBuilderEntry.fromEntries(sharedPartEntries);
    for (final BuilderEntry entry in effectiveEntries) {
      for (final String dep in Set<String>.of(entry.runsBefore)) {
        if (sharedPartEntries.any((BuilderEntryImpl e) => e.key == dep)) {
          entry.runsBefore.remove(dep);
          entry.runsBefore.add(combiningEntry.key);
        }
      }
    }
    effectiveEntries.add(combiningEntry);
  }

  final List<BuilderEntry> orderedEntries = orderBasedOnRunsBefore(
    effectiveEntries,
  );

  final List<List<BuilderEntry>> phases = <List<BuilderEntry>>[
    <BuilderEntry>[],
  ];
  for (final BuilderEntry builder in orderedEntries) {
    if (phases.last.isEmpty) {
      phases.last.add(builder);
    } else {
      final List<BuilderEntry> currentPhase = phases.last;
      if (currentPhase.any(
        (BuilderEntry b) => b.runsBefore.contains(builder.key),
      )) {
        // If the current phase has a builder that runs before the current builder,
        // create a new phase
        phases.add(<BuilderEntry>[builder]);
      } else {
        // Otherwise, add the builder to the current phase
        currentPhase.add(builder);
      }
    }
  }

  return phases;
}

/// {@template order_based_on_runs_before}
/// Performs a topological sort of builders based on their dependency relationships.
///
/// This function:
/// 1. Constructs a directed graph where an edge from A to B means "A runs before B"
/// 2. Uses Kahn's algorithm to perform a topological sort of the graph
/// 3. Detects and reports cycles in the dependency graph
///
/// The resulting order ensures that each builder runs after all the builders
/// it depends on have completed.
///
/// [entries] The list of builder entries to sort
///
/// Returns a list of builder entries in dependency order
///
/// Throws a [StateError] if a cycle is detected in the dependency graph
/// {@endtemplate}
List<BuilderEntry> orderBasedOnRunsBefore(List<BuilderEntry> entries) {
  final Map<String, BuilderEntry> builderMap = <String, BuilderEntry>{
    for (BuilderEntry b in entries) b.key: b,
  };

  final Map<String, Set<String>> graph = <String, Set<String>>{};
  final Map<String, int> inDegree = <String, int>{};

  // Initialize graph
  for (BuilderEntry builder in entries) {
    graph[builder.key] = <String>{};
    inDegree[builder.key] = 0;
  }

  // Build graph edges (A runsBefore B → A depends on B)
  for (BuilderEntry builder in entries) {
    for (String target in builder.runsBefore) {
      if (!builderMap.containsKey(target)) continue;
      graph[builder.key]!.add(target);
      inDegree[target] = inDegree[target]! + 1;
    }
  }
  // Kahn's algorithm for topological sort
  final List<String> queue = <String>[
    for (MapEntry<String, int> entry in inDegree.entries)
      if (entry.value == 0) entry.key,
  ];
  final List<BuilderEntry> sorted = <BuilderEntry>[];

  while (queue.isNotEmpty) {
    final String current = queue.removeAt(0);
    sorted.add(builderMap[current]!);

    for (String neighbor in graph[current]!) {
      inDegree[neighbor] = inDegree[neighbor]! - 1;
      if (inDegree[neighbor] == 0) {
        queue.add(neighbor);
      }
    }
  }

  if (sorted.length != entries.length) {
    throw StateError('Cycle detected in builder dependencies');
  }

  return sorted;
}

/// {@template validate_builder_entries}
/// Validates a list of builder entries for potential conflicts and issues.
///
/// This function checks for:
/// 1. SharedPartBuilders that generate to cache (which is not allowed)
/// 2. Duplicate builder keys (which would cause ambiguity)
/// 3. Output conflicts (multiple builders generating to the same file extension)
///
/// [builderEntries] The list of builder entries to validate
///
/// Throws an [Exception] if any validation issues are found
/// {@endtemplate}
void validateBuilderEntries(List<BuilderEntry> builderEntries) {
  final HashMap<String, Set<String>> checked = HashMap<String, Set<String>>();
  for (final BuilderEntryImpl entry
      in builderEntries.whereType<BuilderEntryImpl>()) {
    if (entry.builder is SharedPartBuilder && entry.generateToCache) {
      throw Exception('Shared builders can not generate to cache');
    }
    if (checked.containsKey(entry.key)) {
      throw Exception('Duplicate builder name detected: ${entry.key}');
    }

    for (final MapEntry<String, Set<String>> checked in checked.entries) {
      for (final String output in entry.builder.outputExtensions) {
        if (entry.builder is! SharedPartBuilder &&
            checked.value.contains(output)) {
          throw Exception(
            'Output conflict detected:\n Both ${entry.key} and ${checked.key} generate to the same output: $output',
          );
        }
      }
    }
    checked[entry.key] = entry.builder.outputExtensions;
  }
}
