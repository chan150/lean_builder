import 'dart:io' show Platform;
import 'dart:math';
import 'package:lean_builder/builder.dart';
import 'package:lean_builder/runner.dart';
import 'package:lean_builder/src/graph/asset_scan_manager.dart';
import 'dart:collection';

List<Set<ProcessableAsset>> calculateChunks(Set<ProcessableAsset> assets) {
  final isolateCount = max(1, Platform.numberOfProcessors - 1);
  final actualIsolateCount = min(isolateCount, assets.length);

  final assetsWithTLM = assets.where((a) => a.tlmFlag.hasNormal).toList();
  final assetsWithoutTLM = assets.where((a) => !a.tlmFlag.hasNormal).toList();

  final chunks = List.generate(actualIsolateCount, (_) => <ProcessableAsset>{});

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
  final effectiveEntries = <BuilderEntry>[];
  final sharedPartEntries = <BuilderEntryImpl>[];

  for (final entry in entries) {
    if (entry is BuilderEntryImpl && entry.builder is SharedPartBuilder) {
      sharedPartEntries.add(entry);
    } else {
      effectiveEntries.add(entry);
    }
  }
  if (sharedPartEntries.isNotEmpty) {
    final combiningEntry = CombiningBuilderEntry.fromEntries(sharedPartEntries);
    for (final entry in effectiveEntries) {
      for (final dep in Set.of(entry.runsBefore)) {
        if (sharedPartEntries.any((e) => e.key == dep)) {
          entry.runsBefore.remove(dep);
          entry.runsBefore.add(combiningEntry.key);
        }
      }
    }
    effectiveEntries.add(combiningEntry);
  }

  final orderedEntries = orderBasedOnRunsBefore(effectiveEntries);

  final phases = <List<BuilderEntry>>[[]];
  for (final builder in orderedEntries) {
    if (phases.last.isEmpty) {
      phases.last.add(builder);
    } else {
      final currentPhase = phases.last;
      if (currentPhase.any((b) => b.runsBefore.contains(builder.key))) {
        // If the current phase has a builder that runs before the current builder,
        // create a new phase
        phases.add([builder]);
      } else {
        // Otherwise, add the builder to the current phase
        currentPhase.add(builder);
      }
    }
  }

  return phases;
}

List<BuilderEntry> orderBasedOnRunsBefore(List<BuilderEntry> entries) {
  final builderMap = {for (var b in entries) b.key: b};

  final graph = <String, Set<String>>{};
  final inDegree = <String, int>{};

  // Initialize graph
  for (var builder in entries) {
    graph[builder.key] = {};
    inDegree[builder.key] = 0;
  }

  // Build graph edges (A runsBefore B → A depends on B)
  for (var builder in entries) {
    for (var target in builder.runsBefore) {
      if (!builderMap.containsKey(target)) continue;
      graph[builder.key]!.add(target);
      inDegree[target] = inDegree[target]! + 1;
    }
  }
  // Kahn's algorithm for topological sort
  final queue = <String>[
    for (var entry in inDegree.entries)
      if (entry.value == 0) entry.key,
  ];
  final sorted = <BuilderEntry>[];

  while (queue.isNotEmpty) {
    final current = queue.removeAt(0);
    sorted.add(builderMap[current]!);

    for (var neighbor in graph[current]!) {
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
  final checked = HashMap<String, Set<String>>();
  for (final entry in builderEntries.whereType<BuilderEntryImpl>()) {
    if (entry.builder is SharedPartBuilder && entry.generateToCache) {
      throw Exception('Shared builders can not generate to cache');
    }
    if (checked.containsKey(entry.key)) {
      throw Exception('Duplicate builder name detected: ${entry.key}');
    }

    for (final checked in checked.entries) {
      for (final output in entry.builder.outputExtensions) {
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
