import 'dart:io';
import 'dart:typed_data';

import 'package:lean_builder/src/resolvers/file_asset.dart';
import 'package:lean_builder/src/resolvers/package_file_resolver.dart';
import 'package:xxh3/xxh3.dart';

class MockPackageFileResolver implements PackageFileResolver {
  final Map<String, String> packageToPath;
  final Map<String, String> pathToPackage;

  @override
  final String packagesHash;

  MockPackageFileResolver()
    : packageToPath = {'test': 'path/to/test'},
      pathToPackage = {'path/to/test': 'test'},
      packagesHash = 'mock-test-hash';

  @override
  Set<String> get packages => {'test'};

  @override
  String packageFor(Uri uri, {Uri? relativeTo}) {
    return 'test';
  }

  @override
  String pathFor(String package) {
    return 'path/to/test';
  }

  @override
  Uri resolveFileUri(Uri uri, {Uri? relativeTo}) {
    return uri;
  }

  @override
  AssetSrc buildAssetUri(Uri uri, {AssetSrc? relativeTo}) {
    return AssetSrc(File.fromUri(uri), uri, xxh3String(Uint8List.fromList(uri.toString().codeUnits)));
  }

  @override
  bool isRootPackage(String package) {
    return package == 'test';
  }

  @override
  Map<String, dynamic> toJson() {
    return {'packages': packageToPath, 'hash': packagesHash};
  }

  @override
  Uri toShortUri(Uri uri) {
    return uri;
  }
}
