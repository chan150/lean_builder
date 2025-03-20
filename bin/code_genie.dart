import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:xxh3/xxh3.dart';

import 'resolvers/package_file_resolver.dart';
import 'scanner/assets_graph.dart';
import 'scanner/top_level_scanner.dart';
import 'utils.dart';

final packageUrl = '/Users/milad/.pub-cache/hosted/pub.dev/args-2.6.0/lib';
final webPackageUrl = '/Users/milad/.pub-cache/hosted/pub.dev/web-1.1.1/lib';
final autoRoutePackageUrl = '/Users/milad/.pub-cache/hosted/pub.dev/auto_route-10.0.0/lib';
final flutterPackageUrl = '/Users/milad/Dev/sdk/flutter/packages/flutter';
final testPackageUrl = '/Users/milad/StudioProjects/code_genie/lib/test';

final assetsGraphFile = File('.dart_tool/build/assets_graph.json');

void main(List<String> args) async {
  final stopWatch = Stopwatch()..start();

  final fileResolver = PackageFileResolver.forCurrentRoot();
  final rootPackage = rootPackageName;
  final AssetsGraph assetsGraph;

  if (assetsGraphFile.existsSync()) {
    final cachedGraph = jsonDecode(assetsGraphFile.readAsStringSync());
    assetsGraph = AssetsGraph.fromCache(cachedGraph, fileResolver);
    if (!assetsGraph.loadedFromCAche) {
      print('Cache is outdated, rebuilding...');
      assetsGraphFile.deleteSync(recursive: true);
    }
  } else {
    assetsGraph = AssetsGraph(fileResolver);
  }

  final scanner = TopLevelScanner(assetsGraph);
  final packagesToScan = assetsGraph.loadedFromCAche || true ? {rootPackage} : fileResolver.packages;
  for (final package in packagesToScan) {
    final packagePath = fileResolver.pathFor(package);
    final packageRoot = '${Uri.parse(packagePath).path}/lib';
    final dir = Directory(packageRoot);
    if (!dir.existsSync()) return;
    final files = dir
        .listSync(recursive: true, followLinks: false)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart') && !file.path.endsWith('.g.dart'));
    for (var file in files) {
      scanner.scanFile(file);
    }
  }
  final packageAssets = assetsGraph.getAssetsForPackage(rootPackage);
  if (assetsGraph.loadedFromCAche) {
    for (final asset in packageAssets) {
      final uri = fileResolver.resolve(Uri.parse(asset.path));
      final file = File.fromUri(uri);
      if (!file.existsSync()) {
        assetsGraph.removeAsset(asset.pathHash);
        continue;
      }
      final content = file.readAsBytesSync();
      final currentHash = xxh3String(content);
      if (currentHash != asset.contentHash) {
        assetsGraph.removeAsset(asset.pathHash);
        scanner.scanFile(file);
      }
    }
  }

  for (final asset in packageAssets) {
    print(asset);
  }

  await assetsGraphFile.writeAsString(jsonEncode(assetsGraph.toJson()));
  print('Time taken: ${stopWatch.elapsed.inMilliseconds} ms');
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
