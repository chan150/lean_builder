import 'dart:convert' show Encoding, utf8;
import 'dart:io' show File;
import 'dart:typed_data' show Uint8List;
import 'package:lean_builder/src/logger.dart';
import 'package:path/path.dart' as p show withoutExtension;

/// {@template asset.description}
/// A representation of a file-based resource.
///
/// Provides a uniform interface for accessing and manipulating files regardless
/// of their source or location. Each asset has a unique [id], a [shortUri] for
/// reference, and a complete [uri] for direct access.
/// {@endtemplate}
abstract class Asset {
  /// {@template asset.id}
  /// A unique identifier for this asset.
  /// it's typically a hash of the asset's [shortUri].
  /// {@endtemplate}
  String get id;

  /// {@template asset.shortUri}
  /// A shortened URI that may use package or asset schemes.
  ///
  /// This often provides a more human-readable reference to the asset
  /// than the full file system URI.
  /// {@endtemplate}
  Uri get shortUri;

  /// {@template asset.uri}
  /// The complete URI that points to this asset.
  ///
  /// This URI can be used to directly access the asset in the file system.
  /// {@endtemplate}
  Uri get uri;

  /// {@template asset.readAsBytesSync}
  /// Reads the entire asset synchronously as a list of bytes.
  ///
  /// Returns a [Uint8List] containing the bytes of the asset.
  /// {@endtemplate}
  Uint8List readAsBytesSync();

  /// {@template asset.readAsStringSync}
  /// Reads the entire asset synchronously as a string.
  ///
  /// Returns the asset contents as a [String].
  ///
  /// The optional [encoding] parameter specifies the encoding to use when
  /// reading the file. It defaults to [utf8].
  /// {@endtemplate}
  String readAsStringSync({Encoding encoding = utf8});

  /// {@template asset.existsSync}
  /// Checks whether the asset exists.
  ///
  /// Returns `true` if the asset exists, `false` otherwise.
  /// {@endtemplate}
  bool existsSync();

  /// {@template asset.constructor}
  /// Creates a new file-based asset.
  ///
  /// Parameters:
  /// - [id]: The unique identifier for this asset.
  /// - [shortUri]: A shortened URI that may use package or asset schemes.
  /// - [file]: The file that this asset represents.
  /// {@endtemplate}
  factory Asset({required String id, required Uri shortUri, required File file}) = FileAsset;

  /// {@template asset.toJson}
  /// Converts this asset to a JSON representation.
  ///
  /// Returns a [Map] containing the serialized form of this asset.
  /// {@endtemplate}
  Map<String, dynamic> toJson();

  /// {@template asset.packageName}
  /// Extracts the package name from the [shortUri].
  ///
  /// Returns:
  /// - For 'package:foo/bar.dart': returns 'foo'
  /// - For 'asset:foo/bar.dart': returns 'foo'
  /// - For 'dart:core/string.dart': returns 'dart'
  /// - For other URI schemes: returns null
  /// {@endtemplate}
  String? get packageName;

  /// {@template asset.uriWithExtension}
  /// Creates a new URI with the same path as this asset but with a different extension.
  ///
  /// The [ext] parameter should include the leading dot (e.g., '.json').
  ///
  /// Returns a new [Uri] with the specified extension.
  /// {@endtemplate}
  Uri uriWithExtension(String ext);

  /// {@template asset.safeDelete}
  /// Safely deletes the asset if it exists.
  ///
  /// Any exceptions during deletion are caught and logged.
  /// {@endtemplate}
  void safeDelete();
}

/// {@macro asset.description}
///
/// This implementation is backed by a [File] in the filesystem.
class FileAsset implements Asset {
  /// The underlying file that this asset represents.
  final File file;

  /// {@macro asset.id}
  @override
  final String id;

  /// {@macro asset.shortUri}
  @override
  final Uri shortUri;

  /// Creates a new FileAsset.
  ///
  /// {@macro asset.constructor}
  FileAsset({required this.file, required this.shortUri, required this.id});

  /// {@macro asset.uri}
  @override
  Uri get uri => file.uri;

  /// {@macro asset.readAsBytesSync}
  @override
  Uint8List readAsBytesSync() {
    return file.readAsBytesSync();
  }

  /// {@macro asset.readAsStringSync}
  @override
  String readAsStringSync({Encoding encoding = utf8}) {
    return file.readAsStringSync(encoding: encoding);
  }

  /// {@macro asset.existsSync}
  @override
  bool existsSync() => file.existsSync();

  @override
  String toString() {
    return 'FileAsset{file: $file, pathHash: $id, packagePath: $shortUri}';
  }

  /// {@macro asset.toJson}
  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{'id': id, 'shortUri': shortUri.toString(), 'uri': uri.toString()};
  }

  /// Creates a new FileAsset from a JSON representation.
  ///
  /// The [json] parameter must contain 'id', 'shortUri', and 'uri' keys.
  ///
  /// Returns a new [FileAsset] instance.
  factory FileAsset.fromJson(Map<String, dynamic> json) {
    return FileAsset(
      file: File.fromUri(Uri.parse(json['uri'] as String)),
      shortUri: Uri.parse(json['shortUri'] as String),
      id: json['id'] as String,
    );
  }

  /// {@macro asset.packageName}
  @override
  String? get packageName {
    return switch (shortUri.scheme) {
      'dart' => 'dart',
      'package' || 'asset' => shortUri.pathSegments.firstOrNull,
      _ => null,
    };
  }

  /// {@macro asset.uriWithExtension}
  @override
  Uri uriWithExtension(String ext) {
    return uri.replace(path: p.withoutExtension(uri.path) + ext);
  }

  /// {@macro asset.safeDelete}
  @override
  void safeDelete() {
    try {
      if (existsSync()) {
        file.deleteSync(recursive: true);
      }
    } catch (e) {
      final StackTrace? stack = e is Error ? e.stackTrace : StackTrace.current;
      Logger.error('Error deleting file ${file.path}', stackTrace: stack);
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FileAsset &&
          runtimeType == other.runtimeType &&
          uri == other.uri &&
          id == other.id &&
          shortUri == other.shortUri;

  @override
  int get hashCode => uri.hashCode ^ id.hashCode ^ shortUri.hashCode;
}
