import 'dart:io';

import 'package:glob/glob.dart';
import 'package:path/path.dart' as p;

import 'asset.dart';
import 'package_file_resolver.dart';

class FileAssetReader {
  final PackageFileResolver fileResolver;

  FileAssetReader(this.fileResolver);

  Map<String, List<Asset>> listAssetsFor(Set<String> packages) {
    final assets = <String, List<Asset>>{};
    for (final package in packages) {
      final collection = <Asset>[];
      final packagePath = fileResolver.pathFor(package);
      final dir = Directory.fromUri(Uri.parse(packagePath));
      assert(dir.existsSync(), 'Package $package not found at ${dir.path}');
      for (final subDir in PackageFileResolver.dirsScheme.keys) {
        /// Skip none-lib directory for non-root packages
        if (subDir != 'lib' && package != fileResolver.rootPackage) continue;
        final subDirPath = Directory(p.join(dir.path, subDir));
        if (subDirPath.existsSync()) {
          _collectAssets(subDirPath, collection);
        }
      }
      assets[package] = collection;
    }
    return assets;
  }

  List<Asset> findRootAssets(Glob glob) {
    final package = fileResolver.rootPackage;
    final packagePath = fileResolver.pathFor(package);
    final dir = Directory.fromUri(Uri.parse(packagePath));
    assert(dir.existsSync(), 'Package $package not found at ${dir.path}');
    final collection = <Asset>[];
    _collectAssets(dir, collection, matcher: glob);
    return collection;
  }

  void _collectAssets(Directory directory, List<Asset> assets, {Glob? matcher}) {
    for (final entity in directory.listSync()) {
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
