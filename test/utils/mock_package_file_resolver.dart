import 'dart:io';
import 'dart:typed_data';

import 'package:lean_builder/src/resolvers/file_asset.dart';
import 'package:lean_builder/src/resolvers/package_file_resolver.dart';
import 'package:xxh3/xxh3.dart';

import '../scanner/string_asset_src.dart';

class MockPackageFileResolver implements PackageFileResolver {
  final Map<String, String> packageToPath;
  final Map<String, String> pathToPackage;

  @override
  final String packagesHash;

  MockPackageFileResolver._(this.packageToPath, this.pathToPackage, this.packagesHash);

  factory MockPackageFileResolver(Map<String, String> packageToPath) {
    return MockPackageFileResolver._(packageToPath, packageToPath.map((k, v) => MapEntry(v, k)), 'hash');
  }

  @override
  Set<String> get packages => Set.of(packageToPath.keys);

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
  AssetSrc assetSrcFor(Uri uri, {AssetSrc? relativeTo}) {
    return StringSrc('', uriString: uri.toString());
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
  Uri toShortUri(Uri uri) => uri;
}
