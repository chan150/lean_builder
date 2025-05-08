import 'package:lean_builder/src/asset/asset.dart';
import 'package:lean_builder/src/asset/assets_reader.dart';
import 'package:lean_builder/src/asset/package_file_resolver.dart';
import 'package:lean_builder/src/graph/references_scanner.dart';

extension TopLevelScannerExt on ReferencesScanner {
  // register the scanned asset in the assets cache so it's not resolved to FileAsset
  void registerAndScan(Asset asset, {Asset? relativeTo}) {
    (fileResolver as PackageFileResolverImpl).registerAsset(
      asset,
      relativeTo: relativeTo,
    );
    scan(asset);
  }
}

void scanDartSdk(
  ReferencesScanner scanner, {
  Set<String> also = const <String>{},
}) {
  final Map<String, List<Asset>> assetsReader = FileAssetReader(
    scanner.fileResolver,
  ).listAssetsFor(<String>{PackageFileResolver.dartSdk, ...also});
  for (final Asset asset in assetsReader.values.expand((List<Asset> e) => e)) {
    scanner.scan(asset);
  }
}
