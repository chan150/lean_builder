import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:xxh3/xxh3.dart';

import 'file_asset.dart';

/// Abstract interface for resolving package file paths
abstract class PackageFileResolver {
  static const dirsScheme = {'lib': 'package', 'test': 'asset'};

  /// Resolves a URI to an absolute URI
  Uri resolve(Uri uri, {Uri? relativeTo});

  /// Returns the package name for a given URI
  String packageFor(Uri uri, {Uri? relativeTo});

  String pathFor(String package);

  /// Converts a file URI to a package import string
  String uriToPackageImport(Uri uri);

  AssetFile buildAssetUri(Uri uri, {AssetFile? relativeTo});

  /// Returns the set of available packages
  Set<String> get packages;

  String get packagesHash;

  /// Creates a resolver for the current working directory
  factory PackageFileResolver.forCurrentRoot(String rootPackage) {
    return PackageFileResolverImpl.forRoot(Directory.current.path, rootPackage);
  }

  factory PackageFileResolver.fromJson(Map<String, dynamic> data) {
    final packageToPath = (data['packageToPath'] as Map<dynamic, dynamic>).cast<String, String>();
    final pathToPackage = Map.of(packageToPath.map((k, v) => MapEntry(v, k)));
    return PackageFileResolverImpl(packageToPath, pathToPackage, data['packagesHash'], data['rootPackage']);
  }

  bool isRootPackage(String package);

  Map<String, dynamic> toJson();
}

/// Implementation of file resolution for Dart package system
class PackageFileResolverImpl implements PackageFileResolver {
  final Map<String, String> packageToPath;
  final Map<String, String> pathToPackage;

  @override
  final String packagesHash;
  final String rootPackage;

  static const _packageConfigPath = '.dart_tool/package_config.json';
  static const _skyEnginePackage = 'sky_engine';
  static const dartSdk = r'$sdk';
  static final dartSdkPath = Uri.file(p.dirname(p.dirname(Platform.resolvedExecutable)));

  PackageFileResolverImpl(this.packageToPath, this.pathToPackage, this.packagesHash, this.rootPackage);

  @override
  Set<String> get packages => packageToPath.keys.toSet();

  @override
  String pathFor(String package) {
    assert(packageToPath.containsKey(package), 'Package $package not found');
    return packageToPath[package]!;
  }

  /// Creates a resolver for the specified root directory
  factory PackageFileResolverImpl.forRoot(String path, String rootPackage) {
    final config = _loadPackageConfig(path);
    return PackageFileResolverImpl(config.packageToPath, config.pathToPackage, config.packagesHash, rootPackage);
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
      String resolvedPath = packageUri.toString();
      if (!packageUri.hasScheme) {
        Uri absoluteUri = packageUri;
        absoluteUri = Directory.current.uri.resolve(packageUri.pathSegments.skip(1).join('/'));
        resolvedPath = absoluteUri.replace(path: p.canonicalize(absoluteUri.path)).toString();
      }

      packageToPath[name] = resolvedPath;
      pathToPackage[resolvedPath] = name;
    }

    final sdkPath = dartSdkPath.toString();
    pathToPackage[sdkPath] = dartSdk;
    packageToPath[dartSdk] = sdkPath;
    return _PackageConfig(packageToPath, pathToPackage, packagesHash);
  }

  @override
  String packageFor(Uri uri, {Uri? relativeTo}) {
    if (uri.scheme == 'dart') {
      return dartSdk;
    }

    final path = resolve(uri, relativeTo: relativeTo).replace(scheme: 'file').toString();
    String? bestMatch;
    int bestMatchLength = 0;
    for (final entry in pathToPackage.entries) {
      final rootPath = entry.key;
      final packageName = entry.value;

      // Check for exact match
      if (path == rootPath) {
        return packageName;
      }
      // Check if uri starts with this root path
      if (path.startsWith(rootPath) && (rootPath.endsWith('/') || path.substring(rootPath.length).startsWith('/'))) {
        // If this match is longer than our current best match, use it
        if (rootPath.length > bestMatchLength) {
          bestMatch = packageName;
          bestMatchLength = rootPath.length;
        }
      }
    }
    if (bestMatch == null) {
      print('Could not find package for $path');
      for (final entry in pathToPackage.entries) {
        print('entry: ${entry.key} => ${entry.value}');
      }
    }

    assert(bestMatch != null, 'Could not find package for $path');
    return bestMatch!;
  }

  Uri toShortPath(Uri uri) {
    if (uri.scheme == 'package') {
      return uri;
    } else if (uri.scheme == 'file') {
      final packageName = packageFor(uri);

      final rootUri = Uri.parse(packageToPath[packageName]!);
      // remove trailing slash if present
      int rootSegLength = rootUri.pathSegments.length;
      if (rootUri.pathSegments.last == '') {
        rootSegLength--;
      }
      final segments = uri.pathSegments.sublist(rootSegLength);
      final dir = segments[0];

      if (packageName == dartSdk) {
        return Uri(scheme: 'dart', pathSegments: segments.skip(1).take(1));
      }

      final scheme = PackageFileResolver.dirsScheme[dir];
      final dirsToSkip = scheme == 'package' ? 1 : 0;
      return Uri(scheme: scheme, pathSegments: [packageName, ...segments.skip(dirsToSkip)]);
    }
    return uri;
  }

  @override
  AssetFile buildAssetUri(Uri uri, {AssetFile? relativeTo}) {
    final absoluteUri = resolve(uri, relativeTo: relativeTo?.uri);

    final packageName = packageFor(absoluteUri);
    final shortPath = toShortPath(absoluteUri);
    final hash = xxh3String(Uint8List.fromList(shortPath.toString().codeUnits));
    return AssetFile(File.fromUri(absoluteUri), shortPath, hash, packageName == rootPackage);
  }

  @override
  Uri resolve(Uri uri, {Uri? relativeTo}) {
    return switch (uri.scheme) {
      'package' => _resolvePackageUri(uri),
      'asset' => _resolveAssetUri(uri),
      'dart' => _resolveDartUri(uri),
      '' => _resolveRelativeUri(uri, relativeTo),
      _ => uri,
    };
  }

  Uri _resolvePackageUri(Uri uri) {
    final package = uri.pathSegments.first;
    final packagePath = packageToPath[package];
    if (packagePath != null) {
      return Uri.parse(p.joinAll([packagePath, 'lib', ...uri.pathSegments.skip(1)]));
    }
    return uri;
  }

  Uri _resolveAssetUri(Uri uri) {
    final package = uri.pathSegments.first;
    final packagePath = packageToPath[package];
    if (packagePath != null) {
      return Uri.parse(p.joinAll([packagePath, ...uri.pathSegments.skip(1)]));
    }
    return uri;
  }

  Uri _resolveDartUri(Uri uri) {
    final dir = uri.path;
    // handle core
    if (uri.pathSegments.length == 1) {
      final sdkPath = packageToPath[dartSdk]!;
      return Uri.parse(p.joinAll([sdkPath, 'lib', dir, '$dir.dart']));
    }

    final packagePath = packageToPath[dir] ?? packageToPath[_skyEnginePackage];
    if (packagePath != null) {
      return Uri.parse(p.joinAll([packagePath, 'lib', dir, '$dir.dart']));
    }
    return uri;
  }

  Uri _resolveRelativeUri(Uri uri, Uri? relativeTo) {
    assert(relativeTo != null, 'Relative URI requires a base URI');
    final baseDir = p.dirname(relativeTo!.path);
    final uriPath = uri.path.startsWith('/') ? uri.path.substring(1) : uri.path;
    final normalized = p.normalize(p.join(baseDir, uriPath));
    return Uri(scheme: 'file', path: normalized);
  }

  @override
  String uriToPackageImport(Uri uri) {
    final splits = uri.path.split('/lib/');
    final package = pathToPackage[splits.firstOrNull];
    assert(package != null, 'Package not found for URI: $uri');
    return 'package:$package/${splits.last}';
  }

  @override
  bool isRootPackage(String package) {
    return package == rootPackage;
  }

  @override
  Map<String, dynamic> toJson() {
    return {'packageToPath': packageToPath, 'packagesHash': packagesHash, 'rootPackage': rootPackage};
  }
}

/// Private class to hold package configuration data
class _PackageConfig {
  final Map<String, String> packageToPath;
  final Map<String, String> pathToPackage;
  final String packagesHash;

  _PackageConfig(this.packageToPath, this.pathToPackage, this.packagesHash);
}
