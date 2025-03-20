import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:xxh3/xxh3.dart';

/// Abstract interface for resolving package file paths
abstract class PackageFileResolver {
  /// Resolves a URI to an absolute URI
  Uri resolve(Uri uri, {Uri? relativeTo});

  /// Returns the package name for a given URI
  String packageFor(Uri uri, {Uri? relativeTo});

  String pathFor(String package);

  /// Converts a file URI to a package import string
  String uriToPackageImport(Uri uri);

  /// Returns the set of available packages
  Set<String> get packages;

  String get packagesHash;

  /// Creates a resolver for the current working directory
  factory PackageFileResolver.forCurrentRoot() {
    return PackageFileResolverImpl.forRoot(Directory.current.path);
  }
}

/// Implementation of file resolution for Dart package system
class PackageFileResolverImpl implements PackageFileResolver {
  final Map<String, String> packageToPath;
  final Map<String, String> pathToPackage;
  @override
  final String packagesHash;

  static const _packageConfigPath = '.dart_tool/package_config.json';
  static const _skyEnginePackage = 'sky_engine';

  PackageFileResolverImpl(this.packageToPath, this.pathToPackage, this.packagesHash);

  @override
  Set<String> get packages => packageToPath.keys.toSet();

  @override
  String pathFor(String package) {
    assert(packageToPath.containsKey(package), 'Package $package not found');
    return packageToPath[package]!;
  }

  /// Creates a resolver for the specified root directory
  factory PackageFileResolverImpl.forRoot(String path) {
    final config = _loadPackageConfig(path);
    return PackageFileResolverImpl(config.packageToPath, config.pathToPackage, config.packagesHash);
  }

  /// Helper method to load and parse package configuration
  static _PackageConfig _loadPackageConfig(String rootPath) {
    final packageConfig = File.fromUri(Uri.file(p.join(rootPath, _packageConfigPath)));
    final json = jsonDecode(packageConfig.readAsStringSync());
    final packageConfigJson = json['packages'] as List<dynamic>;
    final packagesHash = xxh3String(Uint8List.fromList(jsonEncode(packageConfigJson).codeUnits));

    final packageToPath = <String, String>{};
    final pathToPackage = <String, String>{};

    for (var entry in packageConfigJson) {
      final name = entry['name'] as String;
      if (name[0] == '_') continue;

      final packageUri = Uri.parse(entry['rootUri'] as String);
      final absoluteUri =
          packageUri.hasScheme ? packageUri : Directory.current.uri.resolve(packageUri.pathSegments.skip(1).join('/'));

      final resolvedPath = absoluteUri.replace(path: p.canonicalize(absoluteUri.path)).toString();

      packageToPath[name] = resolvedPath;
      pathToPackage[resolvedPath] = name;
    }

    return _PackageConfig(packageToPath, pathToPackage, packagesHash);
  }

  @override
  String packageFor(Uri uri, {Uri? relativeTo}) {
    final parts = resolve(uri, relativeTo: relativeTo).path.split('/lib/');
    return parts.firstOrNull?.split('/').lastOrNull ?? '';
  }

  @override
  Uri resolve(Uri uri, {Uri? relativeTo}) {
    if (uri.isScheme('package')) {
      return _resolvePackageUri(uri);
    } else if (uri.isScheme('dart')) {
      return _resolveDartUri(uri);
    } else if (!uri.hasScheme) {
      return _resolveRelativeUri(uri, relativeTo);
    }
    return uri;
  }

  Uri _resolvePackageUri(Uri uri) {
    final package = uri.pathSegments.first;
    final packagePath = packageToPath[package];
    if (packagePath != null) {
      return Uri.parse(p.joinAll([packagePath, 'lib', ...uri.pathSegments.skip(1)]));
    }
    return uri;
  }

  Uri _resolveDartUri(Uri uri) {
    final packagePath = packageToPath[_skyEnginePackage];
    final dir = uri.path;
    if (packagePath != null) {
      return Uri.parse(p.joinAll([packagePath, 'lib', dir, '$dir.dart']));
    }
    return uri;
  }

  Uri _resolveRelativeUri(Uri uri, Uri? relativeTo) {
    assert(relativeTo != null, 'Relative URI requires a base URI');
    return relativeTo!.resolveUri(uri);
  }

  @override
  String uriToPackageImport(Uri uri) {
    final splits = uri.replace(scheme: 'file').toString().split('/lib/');
    final package = pathToPackage[splits.firstOrNull];
    if (package == null) return uri.toString();
    return 'package:$package/${splits.last}';
  }
}

/// Private class to hold package configuration data
class _PackageConfig {
  final Map<String, String> packageToPath;
  final Map<String, String> pathToPackage;
  final String packagesHash;

  _PackageConfig(this.packageToPath, this.pathToPackage, this.packagesHash);
}
