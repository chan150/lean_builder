import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:xxh3/xxh3.dart';
import 'file_asset.dart';

/// Abstract interface for resolving package file paths
abstract class PackageFileResolver {
  static const dirsScheme = {'lib': 'package', 'test': 'asset'};
  static const dartSdk = r'$sdk';
  static final dartSdkPath = Uri.file(p.dirname(p.dirname(Platform.resolvedExecutable)));

  /// Resolves a URI to an absolute URI
  Uri resolveFileUri(Uri uri, {Uri? relativeTo});

  /// short reversible path
  /// e.g
  /// package:name/src/file.dart
  /// dart:core/bool.dart
  /// asset:package/test/file.dart
  Uri toShortUri(Uri uri);

  /// Returns the package name for a given URI
  String packageFor(Uri uri, {Uri? relativeTo});

  String pathFor(String package);

  /// Converts a file URI to a package import string
  String uriToPackageImport(Uri uri);

  AssetSrc buildAssetUri(Uri uri, {AssetSrc? relativeTo});

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
      String name = entry['name'] as String;
      if (name[0] == '_') continue;
      if (name == _skyEnginePackage) {
        name = PackageFileResolver.dartSdk;
      }
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
    if (!packageToPath.containsKey(PackageFileResolver.dartSdk)) {
      final sdkPath = PackageFileResolver.dartSdkPath.toString();
      pathToPackage[sdkPath] = PackageFileResolver.dartSdk;
      packageToPath[PackageFileResolver.dartSdk] = sdkPath;
    }
    return _PackageConfig(packageToPath, pathToPackage, packagesHash);
  }

  @override
  String packageFor(Uri uri, {Uri? relativeTo}) {
    if (uri.scheme == 'dart') {
      return PackageFileResolver.dartSdk;
    }

    final path = resolveFileUri(uri, relativeTo: relativeTo).replace(scheme: 'file').toString();
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
    assert(bestMatch != null, 'Could not find package for $path');
    return bestMatch!;
  }

  @override
  Uri toShortUri(Uri uri) {
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

      if (packageName == PackageFileResolver.dartSdk) {
        return Uri(scheme: 'dart', pathSegments: segments.skip(1));
      }

      final scheme = PackageFileResolver.dirsScheme[dir];
      final dirsToSkip = scheme == 'package' ? 1 : 0;
      return Uri(scheme: scheme, pathSegments: [packageName, ...segments.skip(dirsToSkip)]);
    }
    return uri;
  }

  final _assetCache = <String, AssetSrc>{};

  @override
  AssetSrc buildAssetUri(Uri uri, {AssetSrc? relativeTo}) {
    final reqId = '$uri@${relativeTo?.uri}';
    if (_assetCache.containsKey(reqId)) {
      return _assetCache[reqId]!;
    }
    assert(!uri.hasEmptyPath, 'URI path cannot be empty');
    final absoluteUri = resolveFileUri(uri, relativeTo: relativeTo?.uri);
    final shortUri = toShortUri(absoluteUri);

    try {
      final hash = xxh3String(Uint8List.fromList(shortUri.toString().codeUnits));
      final asset = AssetSrc(File.fromUri(absoluteUri), shortUri, hash);
      return _assetCache[reqId] = asset;
    } catch (e) {
      print(e);
      rethrow;
    }
  }

  @override
  Uri resolveFileUri(Uri uri, {Uri? relativeTo}) {
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
    final sdkPath = packageToPath[PackageFileResolver.dartSdk]!;

    // Handle special case for dart:core and other standard libraries
    String libraryName = uri.path;

    /// remove the leading underscore
    /// for the internal libraries
    if (libraryName == '_internal') {
      libraryName = libraryName.substring(1);
    }
    // The SDK libraries are typically located at sdk_path/lib/library_name/library_name.dart
    // First try the standard pattern
    final absoluteUri = Uri.parse(p.joinAll([sdkPath, 'lib', libraryName, '$libraryName.dart']));
    if (File.fromUri(absoluteUri).existsSync()) {
      return absoluteUri;
    }

    // Some libraries might be directly in the lib directory
    final directUri = Uri.parse(p.joinAll([sdkPath, 'lib', '$libraryName.dart']));
    if (File.fromUri(directUri).existsSync()) {
      return directUri;
    }

    // For libraries with additional path segments
    if (uri.pathSegments.length > 1) {
      final segments = uri.pathSegments;
      final baseLib = segments.first;
      final fileSegments = segments.sublist(1);
      final libPath = Uri.parse(p.joinAll([sdkPath, 'lib', baseLib, ...fileSegments]));
      if (File.fromUri(libPath).existsSync()) {
        return libPath;
      }
    }

    // If we can't find the file, return the best guess
    return absoluteUri;
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
