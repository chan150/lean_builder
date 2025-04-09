import 'dart:io';

import 'package:code_genie/src/resolvers/file_asset.dart';
import 'package:code_genie/src/resolvers/package_file_resolver.dart';

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
  String uriToPackageImport(Uri uri) {
    final path = uri.toString();
    if (path.startsWith('path/to/test/lib/')) {
      final packagePath = path.replaceFirst('path/to/test/lib/', '');
      return 'package:test/$packagePath';
    }
    return path;
  }

  @override
  AssetSrc buildAssetUri(Uri uri, {AssetSrc? relativeTo}) {
    return AssetSrc(File.fromUri(uri), uri, 'mock-test-hash');
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
