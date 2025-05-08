import 'dart:collection' show HashMap;
import 'dart:io' show Directory, File, FileSystemEntity;

import 'package:glob/glob.dart' show Glob;
import 'package:path/path.dart' as p show join;

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
  /// Finds assets in the root package that match the specified [glob] pattern.
  ///
  /// This method recursively searches all directories in the root package
  /// and returns a list of [Asset] objects for files that match the [glob].
  /// {@endtemplate}
  List<Asset> findRootAssets(Glob glob) {
    final String package = fileResolver.rootPackage;
    final String packagePath = fileResolver.pathFor(package);
    final Directory dir = Directory.fromUri(Uri.parse(packagePath));
    assert(dir.existsSync(), 'Package $package not found at ${dir.path}');
    final List<Asset> collection = <Asset>[];
    _collectAssets(dir, collection, matcher: glob);
    return collection;
  }

  /// Recursively collects assets from a directory.
  ///
  /// Adds found assets to the [assets] list, optionally filtering by [matcher].
  void _collectAssets(Directory directory, List<Asset> assets, {Glob? matcher}) {
    for (final FileSystemEntity entity in directory.listSync()) {
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
