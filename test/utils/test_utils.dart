import 'package:lean_builder/src/asset/asset.dart';
import 'package:lean_builder/src/asset/assets_reader.dart';
import 'package:lean_builder/src/asset/package_file_resolver.dart';
import 'package:lean_builder/src/graph/assets_scanner.dart';

extension TopLevelScannerExt on AssetsScanner {
  // register the scanned asset in the assets cache so it's not resolved to FileAsset
  void registerAndScan(Asset asset, {Asset? relativeTo}) {
    (fileResolver as PackageFileResolverImpl).registerAsset(asset, relativeTo: relativeTo);
    scan(asset);
  }
}

void scanDartSdk(AssetsScanner scanner, {Set<String> also = const {}}) {
  final assetsReader = FileAssetReader(scanner.fileResolver).listAssetsFor({PackageFileResolver.dartSdk, ...also});
  for (final asset in assetsReader.values.expand((e) => e)) {
    scanner.scan(asset);
  }
}
