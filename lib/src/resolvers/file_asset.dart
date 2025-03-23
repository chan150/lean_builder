import 'dart:io';
import 'dart:typed_data';

class FileAsset {
  final File file;
  final String id;

  final Uri shortPath;

  final bool root;

  FileAsset(this.file, this.shortPath, this.id, this.root);

  String get path => file.path;

  Uri get uri => file.uri;

  String? readAsStringSyncSafe() {
    if (!file.existsSync()) return null;
    return file.readAsStringSync();
  }

  Uint8List? readAsBytesSyncSafe() {
    if (!file.existsSync()) return null;
    return file.readAsBytesSync();
  }

  Uint8List readAsBytesSync() {
    return file.readAsBytesSync();
  }

  bool existsSync() => file.existsSync();

  @override
  String toString() {
    return 'FileAsset{file: $file, pathHash: $id, packagePath: $shortPath}';
  }

  //
  // factory FileAsset.fromUri(Uri uri, {FileAsset? relativeTo}) {
  //   Uri effectiveUri = uri;
  //   if (!effectiveUri.isAbsolute) {
  //     assert(relativeTo != null, 'Relative uri must have a relativeTo argument');
  //     effectiveUri = relativeTo!.uri.resolveUri(uri);
  //   }
  //   String? shortPath;
  //   for (final dir in _dirs) {
  //     final segments = effectiveUri.pathSegments;
  //     final dirIndex = segments.indexOf(dir);
  //     if (dirIndex != -1 && dirIndex < segments.length - 1) {
  //       shortPath = segments.sublist(dirIndex - 1).join('/');
  //       break;
  //     }
  //   }
  //   assert(shortPath != null, 'Uri $uri is not in a known package directory');
  //   final hash = xxh3String(Uint8List.fromList(shortPath!.codeUnits));
  //   return FileAsset(File.fromUri(effectiveUri), shortPath, hash);
  // }
}
