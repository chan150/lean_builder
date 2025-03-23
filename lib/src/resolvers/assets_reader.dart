import 'dart:io';

import 'package:path/path.dart' as p;

import 'file_asset.dart';
import 'package_file_resolver.dart';

class FileAssetReader {
  final PackageFileResolver fileResolver;

  FileAssetReader(this.fileResolver);

  bool isValid(File file) {
    return file.path.endsWith('.dart') && !file.path.endsWith('.g.dart');
  }

  Map<String, List<AssetFile>> listAssetsFor(Set<String> packages) {
    final assets = <String, List<AssetFile>>{};
    for (final package in packages) {
      final collection = <AssetFile>[];
      final packagePath = fileResolver.pathFor(package);
      final dir = Directory.fromUri(Uri.parse(packagePath));
      assert(dir.existsSync(), 'Package $package not found at ${dir.path}');
      for (final subDir in PackageFileResolver.dirsScheme.keys) {
        /// Skip test directory for non-root packages
        if (subDir == 'test' && !fileResolver.isRootPackage(package)) continue;
        final subDirPath = Directory(p.join(dir.path, subDir));
        if (subDirPath.existsSync()) {
          _collectAssets(subDirPath, collection);
        }
      }
      assets[package] = collection;
    }
    return assets;
  }

  void _collectAssets(Directory directory, List<AssetFile> assets) {
    for (final entity in directory.listSync()) {
      final basename = entity.uri.pathSegments.last;
      if (basename.startsWith('_')) continue;
      if (entity is Directory) {
        _collectAssets(entity, assets);
      } else if (entity is File && isValid(entity)) {
        assets.add(fileResolver.buildAssetUri(entity.uri));
      }
    }
  }
}
