import 'dart:io' show Platform;
import 'dart:math';
import 'package:lean_builder/builder.dart';
import 'package:lean_builder/runner.dart';
import 'dart:collection';

import 'package:lean_builder/src/graph/references_scan_manager.dart';

List<Set<ProcessableAsset>> calculateChunks(Set<ProcessableAsset> assets) {
  final int isolateCount = max(1, Platform.numberOfProcessors - 1);
  final int actualIsolateCount = min(isolateCount, assets.length);

  final List<ProcessableAsset> assetsWithTLM = assets.where((ProcessableAsset a) => a.tlmFlag.hasNormal).toList();
  final List<ProcessableAsset> assetsWithoutTLM = assets.where((ProcessableAsset a) => !a.tlmFlag.hasNormal).toList();

  final List<Set<ProcessableAsset>> chunks = List.generate(actualIsolateCount, (_) => <ProcessableAsset>{});

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
    final CombiningBuilderEntry combiningEntry = CombiningBuilderEntry.fromEntries(sharedPartEntries);
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

  final List<BuilderEntry> orderedEntries = orderBasedOnRunsBefore(effectiveEntries);

  final List<List<BuilderEntry>> phases = <List<BuilderEntry>>[<BuilderEntry>[]];
  for (final BuilderEntry builder in orderedEntries) {
    if (phases.last.isEmpty) {
      phases.last.add(builder);
    } else {
      final List<BuilderEntry> currentPhase = phases.last;
      if (currentPhase.any((BuilderEntry b) => b.runsBefore.contains(builder.key))) {
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

List<BuilderEntry> orderBasedOnRunsBefore(List<BuilderEntry> entries) {
  final Map<String, BuilderEntry> builderMap = <String, BuilderEntry>{for (BuilderEntry b in entries) b.key: b};

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

// validate the following:
// - shared part builders can not generate to cache
// - duplicate builder keys
// - detect output conflicts
void validateBuilderEntries(List<BuilderEntry> builderEntries) {
  final HashMap<String, Set<String>> checked = HashMap<String, Set<String>>();
  for (final BuilderEntryImpl entry in builderEntries.whereType<BuilderEntryImpl>()) {
    if (entry.builder is SharedPartBuilder && entry.generateToCache) {
      throw Exception('Shared builders can not generate to cache');
    }
    if (checked.containsKey(entry.key)) {
      throw Exception('Duplicate builder name detected: ${entry.key}');
    }

    for (final MapEntry<String, Set<String>> checked in checked.entries) {
      for (final String output in entry.builder.outputExtensions) {
        if (checked.value.contains(output)) {
          throw Exception(
            'Output conflict detected:\n Both ${entry.key} and ${checked.key} generate to the same output: $output',
          );
        }
      }
    }
    checked[entry.key] = entry.builder.outputExtensions;
  }
}
