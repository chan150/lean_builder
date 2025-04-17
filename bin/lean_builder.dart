import 'dart:io';
import 'dart:isolate';

import 'package:dart_style/dart_style.dart';
import 'package:lean_builder/src/resolvers/element/element.dart';
import 'package:lean_builder/src/resolvers/element_resolver.dart';
import 'package:lean_builder/src/resolvers/package_file_resolver.dart';
import 'package:lean_builder/src/resolvers/parsed_units_cache.dart';
import 'package:lean_builder/src/scanner/assets_graph.dart';
import 'package:lean_builder/src/scanner/isolate_scanner.dart';
import 'package:lean_builder/src/utils.dart';

void main(List<String> args) async {
  final stopWatch = Stopwatch()..start();
  // print('Running Fresh Version');
  // if (AssetsGraph.cacheFile.existsSync()) {
  //   AssetsGraph.cacheFile.deleteSync(recursive: true);
  // }

  // final rootPackageName = 'gen_benchmark';

  final fileResolver = PackageFileResolver.forCurrentRoot(rootPackageName);
  final assetsGraph = AssetsGraph.init(fileResolver.packagesHash);

  final isoTlScanner = IsolateTLScanner(assetsGraph: assetsGraph, fileResolver: fileResolver);
  await isoTlScanner.scanAssets();

  print('Updating Graph took: ${stopWatch.elapsed.inMilliseconds} ms');
  stopWatch.reset();

  final parser = SrcParser();
  final resolver = ElementResolver(assetsGraph, fileResolver, parser);
  print('Resolving assets inside $rootPackageName');
  final assets = assetsGraph.getAssetsForPackage(rootPackageName).where((e) => e.hasAnnotation).toList();
  // final packageAssets = assetsGraph.getAssetsForPackage(rootPackageName);

  final isolateCount = Platform.numberOfProcessors - 1;
  final actualIsolateCount = isolateCount.clamp(1, assets.length);
  final chunkSize = (assets.length / actualIsolateCount).ceil();
  final chunks = <List<ScannedAsset>>[];
  final formatter = DartFormatter(languageVersion: DartFormatter.latestLanguageVersion);

  for (int i = 0; i < assets.length; i += chunkSize) {
    final end = (i + chunkSize < assets.length) ? i + chunkSize : assets.length;
    chunks.add(assets.sublist(i, end));
  }

  final futures = <Future>[];
  for (final chunk in chunks) {
    final future = Isolate.run(() async {
      int count = 0;
      final chunkStopWatch = Stopwatch()..start();
      final chunkResolver = ElementResolver(assetsGraph, fileResolver, parser);

      final annotationType = chunkResolver.getNamedTypeRef('Genix', 'package:lean_builder/test/annotation.dart');
      for (final asset in chunk) {
        if (asset.hasAnnotation) {
          final assetFile = fileResolver.assetSrcFor(asset.uri);
          count++;
          final library =
              chunkResolver.resolveLibrary(assetFile, preResolveTopLevelMetadata: true) as LibraryElementImpl;
          final element = library.resolvedElements.firstOrNull;
          if (element != null) {
            print(
              element.metadata.any((a) {
                return annotationType.refersTo(a.type);
              }),
            );
            // print('${element.name} ${element.metadata}');
            // final targetUri = element.librarySrc.uri.replace(
            //   path: element.librarySrc.uri.path.replaceFirst('.dart', '.g.dart'),
            // );
            // String content = element.library.compilationUnit.toSource();
            // content = content.replaceAll('@JsonSerializable()', '');
            // await File.fromUri(targetUri).writeAsString(formatter.format(content, uri: targetUri));
          }
        }
      }
      print('Chunk took: ${chunkStopWatch.elapsed.inMilliseconds} ms, count: $count');
    });
    futures.add(future);
  }
  await Future.wait(futures);

  // for (final asset in assets) {
  //   final assetFile = fileResolver.buildAssetUri(asset.uri);
  //
  //   if (asset.hasAnnotation) {
  //     // count++;
  //
  //     final library = resolver.resolveLibrary(assetFile) as LibraryElementImpl;
  //     final element = library.resolvedElements.firstOrNull;
  //     if (element != null) {
  //       for (final e in element.metadata) {
  //         print('Metadata: ${e.type} ${e.constant}');
  //       }
  //       return;
  //       for (final clazz in library.classes) {
  //         print('Class: ${clazz.name} --------------------- *** ');
  //         print(clazz.metadata);
  //         for (final constructor in clazz.constructors) {
  //           for (final param in constructor.parameters) {
  //             print('${param.type} ${param.name}');
  //           }
  //
  //           // final type = field.type;
  //           // if (element is TypeAliasElement && type is NamedTypeRef) {
  //           //   print(element.instantiate(type));
  //           // }
  //
  //           // final type = field.type;
  //           // if (type is NamedTypeRef) {
  //           //   print(
  //           //     'LocationOfType: ${assetsGraph.getUriForAsset(type.src.srcId)}  providedBy: ${assetsGraph.getUriForAsset(type.src.providerId)}',
  //           //   );
  //           // }
  //         }
  //
  //         // for (final directive in library.directives) {
  //         //   final subLib = directive.referencedLibrary;
  //         //   print(subLib.classes.map((e) => e.name));
  //         // }
  //
  //         // print('Params -----------');
  //         // for (final param in [...?clazz.constructors.firstOrNull?.parameters]) {
  //         //   print('${param.type} ${param.name} ');
  //         // }
  //       }
  //       // print('Asset: took: ${assetStopWatch.elapsed.inMilliseconds} ms');
  //     }
  //   }

  print('Resolving took: ${stopWatch.elapsed.inMilliseconds} ms');
}
