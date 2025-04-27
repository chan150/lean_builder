import 'dart:io';

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
        /// Skip test and bin directory for non-root packages
        if (subDir != 'lib' && package != fileResolver.rootPackage) continue;
        final subDirPath = Directory(p.join(dir.path, subDir));
        if (subDirPath.existsSync()) {
          _collectAssets(package, subDirPath, collection);
        }
      }
      assets[package] = collection;
    }
    return assets;
  }

  void _collectAssets(String package, Directory directory, List<Asset> assets) {
    for (final entity in directory.listSync()) {
      if (entity is Directory) {
        _collectAssets(package, entity, assets);
      } else if (entity is File) {
        assets.add(fileResolver.assetForUri(entity.uri));
      }
    }
  }
}
