import 'package:code_genie/src/resolvers/element_resolver.dart';
import 'package:code_genie/src/resolvers/package_file_resolver.dart';
import 'package:code_genie/src/resolvers/parsed_units_cache.dart';
import 'package:code_genie/src/resolvers/type/type_ref.dart';
import 'package:code_genie/src/scanner/assets_graph.dart';
import 'package:code_genie/src/scanner/isolate_scanner.dart';
import 'package:code_genie/src/utils.dart';

void main(List<String> args) async {
  final stopWatch = Stopwatch()..start();
  // print('Running Fresh Version');
  // if (AssetsGraph.cacheFile.existsSync()) {
  //   AssetsGraph.cacheFile.deleteSync(recursive: true);
  // }

  final fileResolver = PackageFileResolver.forCurrentRoot(rootPackageName);
  final assetsGraph = AssetsGraph.init(fileResolver.packagesHash);

  final isoTlScanner = IsolateTLScanner(assetsGraph: assetsGraph, fileResolver: fileResolver);
  await isoTlScanner.scanAssets();

  print('Updating Graph took: ${stopWatch.elapsed.inMilliseconds} ms');
  stopWatch.reset();

  final parser = SrcParser();
  final resolver = ElementResolver(assetsGraph, fileResolver, parser);
  final packageAssets = assetsGraph.getAssetsForPackage('listize');
  // final packageAssets = assetsGraph.getAssetsForPackage(rootPackageName);
  int count = 0;
  for (final asset in packageAssets) {
    final assetFile = fileResolver.buildAssetUri(asset.uri);

    if (asset.hasAnnotation) {
      count++;
      final assetStopWatch = Stopwatch()..start();

      final library = resolver.resolveLibrary(assetFile);
      for (final clazz in library.classes) {
        print('Class: ${clazz.name} --------------------- *** ');
        print('Fields -----------');
        for (final field in clazz.fields) {
          print('${field.type} ${field.name} ');
          // final type = field.type;
          // if (type is NamedTypeRef) {
          //   print(
          //     'LocationOfType: ${assetsGraph.getUriForAsset(type.src.srcId)}  providedBy: ${assetsGraph.getUriForAsset(type.src.providerId)}',
          //   );
          // }
        }
        print('Params -----------');
        for (final param in [...?clazz.constructors.firstOrNull?.parameters]) {
          print('${param.type} ${param.name} ');
        }
      }
      print('Asset: took: ${assetStopWatch.elapsed.inMilliseconds} ms');
    }
  }

  print('Resolving took: ${stopWatch.elapsed.inMilliseconds} ms, count: $count');
}
