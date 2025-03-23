import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:code_genie/src/resolvers/assets_reader.dart';
import 'package:code_genie/src/resolvers/package_file_resolver.dart';
import 'package:code_genie/src/scanner/assets_graph.dart';
import 'package:code_genie/src/scanner/top_level_scanner.dart';
import 'package:code_genie/src/utils.dart';
import 'package:xxh3/xxh3.dart';

final packageUrl = '/Users/milad/.pub-cache/hosted/pub.dev/args-2.6.0/lib';
final webPackageUrl = '/Users/milad/.pub-cache/hosted/pub.dev/web-1.1.1/lib';
final autoRoutePackageUrl = '/Users/milad/.pub-cache/hosted/pub.dev/auto_route-10.0.0/lib';
final flutterPackageUrl = '/Users/milad/Dev/sdk/flutter/packages/flutter';
final testPackageUrl = '/Users/milad/StudioProjects/code_genie/lib/test';

final assetsGraphFile = File('.dart_tool/build/assets_graph.json');

void main(List<String> args) async {
  final stopWatch = Stopwatch()..start();

  final fileResolver = PackageFileResolver.forCurrentRoot(rootPackageName);
  final AssetsGraph assetsGraph;

  if (assetsGraphFile.existsSync()) {
    final cachedGraph = jsonDecode(assetsGraphFile.readAsStringSync());
    assetsGraph = AssetsGraph.fromCache(cachedGraph, fileResolver.packagesHash);
    if (!assetsGraph.loadedFromCache) {
      print('Cache is outdated, rebuilding...');
      assetsGraphFile.deleteSync(recursive: true);
    }
  } else {
    assetsGraph = AssetsGraph(fileResolver.packagesHash);
  }

  final scanner = TopLevelScanner(assetsGraph, fileResolver);
  final assetsReader = FileAssetReader(fileResolver);
  final packagesToScan = assetsGraph.loadedFromCache ? {rootPackageName} : fileResolver.packages;

  final assets = assetsReader.listAssetsFor(packagesToScan);
  final futures = <Future>[];
  for (final package in assets.keys) {
    final future = Isolate.run(() {
      for (final asset in assets[package]!) {
        scanner.scanFile(asset);
      }
    });
    futures.add(future);
  }
  Future.wait(futures);
  if (assetsGraph.loadedFromCache) {
    for (final entry in assetsGraph.getAssetsForPackage(rootPackageName)) {
      final asset = fileResolver.buildAssetUri(entry.uri);
      if (!asset.existsSync()) {
        assetsGraph.removeAsset(asset.id);
        continue;
      }
      final content = asset.readAsBytesSync();
      final currentHash = xxh3String(content);
      if (currentHash != entry.contentHash) {
        assetsGraph.removeAsset(asset.id);
        scanner.scanFile(asset);
      }
    }
  }

  // final packageAssets = assetsGraph.getAssetsForPackage(rootPackageName);
  // for (final asset in packageAssets) {
  //   // print(assetsGraph.getIdentifierRef('Container', asset.id));
  //   // if (asset.hasAnnotation && asset.uri.isScheme('package')) {
  //   //
  //   //   final unit = getUnitForAsset(fileResolver, fileAsset.path);
  //   //   final clazz = unit.declarations.whereType<ClassDeclaration>().firstWhere((e) => e.metadata.isNotEmpty);
  //   //   final superClass = clazz.extendsClause!.superclass.name2.lexeme;
  //   //   print(superClass);
  //   //
  //   //   final ref = assetsGraph.getIdentifierRef(superClass, fileAsset.id);
  //   //   if (ref != null) {
  //   //     final superAsset = fileResolver.buildAssetUri(ref.srcUri);
  //   //     final superUnit = getUnitForAsset(fileResolver, superAsset.path);
  //   //     final superClazz = superUnit.declarations.whereType<ClassDeclaration>().firstWhere(
  //   //       (e) => e.name.lexeme == ref.identifier,
  //   //     );
  //   //     print(superClazz);
  //   //     print('src: ${ref.srcUri}');
  //   //     print('provider: ${assetsGraph.assets[ref.providerId]?[0]}');
  //   //   }
  //   // }
  // }

  // for (final asset in packageAssets) {
  //   print(asset);
  // }

  await assetsGraphFile.writeAsString(jsonEncode(assetsGraph.toJson()));
  print('Time taken: ${stopWatch.elapsed.inMilliseconds} ms');
}

CompilationUnit getUnitForAsset(PackageFileResolver fileResolver, String path) {
  if (_unitsCache.containsKey(path)) {
    return _unitsCache[path]!;
  }
  final unit = parseFile(path: path, featureSet: FeatureSet.latestLanguageVersion()).unit;
  _unitsCache[path] = unit;
  return unit;
}

final _unitsCache = <String, CompilationUnit>{};

// Set<String> resolveIdentifiers(String identifier, ExportsGraph graph) {
//   final source = graph.getSourceForIdentifier(identifier);
//   if (source == null) return {};
//   final CompilationUnit unit;
//   if (_unitsCache.containsKey(source.path)) {
//     unit = _unitsCache[source.path]!;
//   } else {
//     unit = parseFile(path: source.path, featureSet: FeatureSet.latestLanguageVersion()).unit;
//     _unitsCache[source.path] = unit;
//   }
//   final identifierUnit = unit.declarations.whereType<NamedCompilationUnitMember>().firstWhere(
//     (e) => e.name.lexeme == identifier,
//   );
//
//   for (final import in unit.directives.whereType<ImportDirective>()) {
//     final importUri = Uri.parse(import.uri.stringValue!);
//   }
//
//   final identity = <String>{identifier};
//   if (identifierUnit is ClassDeclaration) {
//     if (identifierUnit.extendsClause != null) {
//       final superClass = identifierUnit.extendsClause!.superclass.name2.lexeme;
//       identity.addAll(resolveIdentifiers(superClass, graph));
//     }
//     if (identifierUnit.withClause != null) {
//       for (final mixin in identifierUnit.withClause!.mixinTypes) {
//         final mixinName = mixin.name2.lexeme;
//         identity.addAll(resolveIdentifiers(mixinName, graph));
//       }
//     }
//     if (identifierUnit.implementsClause != null) {
//       for (final impl in identifierUnit.implementsClause!.interfaces) {
//         final implName = impl.name2.lexeme;
//         identity.addAll(resolveIdentifiers(implName, graph));
//       }
//     }
//   }
//
//   return identity;
// }
