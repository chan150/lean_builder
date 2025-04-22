import 'package:lean_builder/src/resolvers/assets_reader.dart';
import 'package:lean_builder/src/resolvers/file_asset.dart';
import 'package:lean_builder/src/resolvers/package_file_resolver.dart';
import 'package:lean_builder/src/scanner/symbols_scanner.dart';

extension TopLevelScannerExt on SymbolsScanner {
  // register the scanned asset in the assets cache so it's not resolved to FileAsset
  void scanAndRegister(Asset asset, {Asset? relativeTo}) {
    scan(asset);
    (fileResolver as PackageFileResolverImpl).registerAsset(asset, relativeTo: relativeTo);
  }
}

void scanDartCoreAssets(SymbolsScanner scanner) {
  final assetsReader = FileAssetReader(scanner.fileResolver).listAssetsFor({PackageFileResolver.dartSdk, 'meta'});
  for (final asset in assetsReader.values.expand((e) => e)) {
    scanner.scan(asset);
  }
}
