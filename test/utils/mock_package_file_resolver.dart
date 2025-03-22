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
  Uri resolve(Uri uri, {Uri? relativeTo}) {
    if (uri.isScheme('package') && uri.pathSegments.first == 'test') {
      final restPath = uri.pathSegments.skip(1).join('/');
      return Uri.parse('path/to/test/lib/$restPath');
    } else if (uri.isScheme('dart')) {
      return Uri.parse('path/to/sky_engine/lib/${uri.path}/${uri.path}.dart');
    } else if (!uri.hasScheme && relativeTo != null) {
      return relativeTo.resolveUri(uri);
    }
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
  FileAsset buildAssetUri(Uri uri, {FileAsset? relativeTo}) {
    return FileAsset(File.fromUri(uri), uri, 'mock-test-hash', true);
  }

  @override
  bool isRootPackage(String package) {
    return package == 'test';
  }
}
