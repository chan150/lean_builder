import 'dart:io';

import 'package:path/path.dart' as p;

import 'file_asset.dart';
import 'package_file_resolver.dart';

class FileAssetReader {
  final PackageFileResolver fileResolver;

  FileAssetReader(this.fileResolver);

  bool isValid(String package, File file) {
    return file.path.endsWith('.dart');
  }

  Map<String, List<Asset>> listAssetsFor(Set<String> packages) {
    final assets = <String, List<Asset>>{};
    for (final package in packages) {
      final collection = <Asset>[];
      final packagePath = fileResolver.pathFor(package);
      final dir = Directory.fromUri(Uri.parse(packagePath));
      assert(dir.existsSync(), 'Package $package not found at ${dir.path}');
      for (final subDir in PackageFileResolver.dirsScheme.keys) {
        /// Skip test directory for non-root packages
        if (subDir == 'test' && package != fileResolver.rootPackage) continue;
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
        // if (p.basename(entity.path).startsWith('_')) {
        //   print('Skipping private directory: ${entity.path}');
        // }

        _collectAssets(package, entity, assets);
      } else if (entity is File && isValid(package, entity)) {
        assets.add(fileResolver.assetForUri(entity.uri));
      }
    }
  }
}
