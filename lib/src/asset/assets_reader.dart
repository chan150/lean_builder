import 'dart:collection' show HashMap;
import 'dart:io' show Directory, File, FileSystemEntity;

import 'package:glob/glob.dart' show Glob;
import 'package:path/path.dart' as p show join, Context;

import 'asset.dart';
import 'package_file_resolver.dart';

/// {@template file_asset_reader.description}
/// A class that reads file assets from the filesystem.
///
/// This class works with the [PackageFileResolver] to locate and read files
/// from Dart packages, converting them into [Asset] instances for further processing.
/// {@endtemplate}
class FileAssetReader {
  /// {@template file_asset_reader.file_resolver}
  /// The resolver used to convert between package paths and filesystem paths.
  /// {@endtemplate}
  final PackageFileResolver fileResolver;

  /// Creates a new [FileAssetReader] with the given [fileResolver].
  FileAssetReader(this.fileResolver);

  /// {@template file_asset_reader.list_assets_for}
  /// Lists all assets in the specified [packages].
  ///
  /// For each package, this method collects all files from relevant directories.
  /// For the root package, this includes all directories specified in [PackageFileResolver.dirsScheme].
  /// For non-root packages, only files in the 'lib' directory are collected.
  ///
  /// Returns a map where keys are package names and values are lists of [Asset] objects.
  /// {@endtemplate}
  Map<String, List<Asset>> listAssetsFor(Set<String> packages) {
    final Map<String, List<Asset>> assets = HashMap<String, List<Asset>>();
    for (final String package in packages) {
      final List<Asset> collection = <Asset>[];
      final String packagePath = fileResolver.pathFor(package);
      final Directory dir = Directory.fromUri(Uri.parse(packagePath));
      assert(dir.existsSync(), 'Package $package not found at ${dir.path}');
      for (final String subDir in PackageFileResolver.dirsScheme.keys) {
        /// Skip none-lib directory for non-root packages
        if (subDir != 'lib' && package != fileResolver.rootPackage) continue;
        final Directory subDirPath = Directory(p.join(dir.path, subDir));
        if (subDirPath.existsSync()) {
          _collectAssets(subDirPath, collection);
        }
      }
      assets[package] = collection;
    }
    return assets;
  }

  /// {@template file_asset_reader.find_root_assets}
  /// Finds assets in the root package that match the specified [matcher] pattern.
  ///
  /// This method recursively searches all directories in the root package
  /// and returns a list of [Asset] objects for files that match the [matcher].
  ///
  /// The [subDir] parameter allows filtering assets within a specific subdirectory
  /// of the root package. If [subDir] is provided, it should be a relative path
  /// from the root package directory.
  /// {@endtemplate}
  List<Asset> findRootAssets(PathMatcher matcher, {String? subDir}) {
    final String package = fileResolver.rootPackage;
    final String packagePath = fileResolver.pathFor(package);
    final Directory dir = Directory.fromUri(Uri.parse(p.join(packagePath, subDir)));
    assert(dir.existsSync(), 'Package $package not found at ${dir.path}');
    final List<Asset> collection = <Asset>[];
    _collectAssets(dir, collection, matcher: matcher);
    return collection;
  }

  /// Recursively collects assets from a directory.
  ///
  /// Adds found assets to the [assets] list, optionally filtering by [matcher].
  void _collectAssets(
    Directory directory,
    List<Asset> assets, {
    PathMatcher? matcher,
  }) {
    for (final FileSystemEntity entity in directory.listSync(followLinks: false)) {
      if (entity is Directory) {
        _collectAssets(entity, assets, matcher: matcher);
      } else if (entity is File) {
        if (matcher != null && !matcher.matches(entity.path)) {
          continue;
        }
        assets.add(fileResolver.assetForUri(entity.uri));
      }
    }
  }
}

/// An abstract class for matching paths against a pattern.
abstract class PathMatcher {
  /// Checks if the given [path] matches the pattern.
  bool matches(String path);

  /// Creates a Glob-based [PathMatcher] from a glob pattern.
  factory PathMatcher.glob(
    String pattern, {
    p.Context? context,
    bool recursive = false,
    bool? caseSensitive,
  }) {
    return GlobPathMatcher(
      Glob(
        pattern,
        context: context,
        recursive: recursive,
        caseSensitive: caseSensitive,
      ),
    );
  }

  /// Creates a Regex-based [PathMatcher] from a regular expression pattern.
  factory PathMatcher.regex(
    String pattern, {
    bool caseSensitive = true,
    bool unicode = false,
    bool dotAll = false,
  }) {
    return RegexPathMatcher(
      RegExp(
        pattern,
        caseSensitive: caseSensitive,
        unicode: unicode,
        dotAll: dotAll,
      ),
    );
  }

  /// Creates a [PathMatcher] that uses a callback function to match paths.
  factory PathMatcher.callback(
    bool Function(String path) callback,
  ) {
    return CallbackPathMatcher(callback);
  }
}

/// A [PathMatcher] implementation that uses a [Glob] pattern to match paths.
///
/// This class provides a way to match file paths against glob patterns,
class GlobPathMatcher implements PathMatcher {
  /// The glob pattern to match against.
  final Glob _glob;

  /// Creates a [GlobPathMatcher] with the specified [glob] pattern.
  GlobPathMatcher(this._glob);

  @override
  bool matches(String path) {
    return _glob.matches(path);
  }
}

/// A [PathMatcher] implementation that uses a regular expression to match paths.
///
/// This class provides a way to match file paths against regular expression patterns,
class RegexPathMatcher implements PathMatcher {
  final RegExp _regex;

  /// Creates a [RegexPathMatcher] with the specified [regex] pattern.
  RegexPathMatcher(this._regex);

  @override
  bool matches(String path) {
    return _regex.hasMatch(path);
  }
}

// callback matcher
/// A [PathMatcher] implementation that uses a callback function to match paths.
///
/// This class provides a way to match file paths against custom logic defined in a callback function.
class CallbackPathMatcher implements PathMatcher {
  final bool Function(String path) _callback;

  /// Creates a [CallbackPathMatcher] with the specified [callback] function.
  CallbackPathMatcher(this._callback);

  @override
  bool matches(String path) {
    return _callback(path);
  }
}
