import 'dart:io';

import 'package:lean_builder/src/errors/resolver_error.dart';
import 'package:lean_builder/src/resolvers/package_file_resolver.dart';
import 'package:test/test.dart';

void main() {
  late final PackageFileResolverImpl fileResolver;
  setUpAll(() {
    fileResolver = PackageFileResolverImpl(
      {
        'lean_builder': 'file:///root/lean_builder-1.0.0',
        'git': 'file:///root/git/vertex_core-12345/',
        r'$sdk': 'file:///sdk-path',
      },
      {
        'file:///root/lean_builder-1.0.0': 'lean_builder',
        'file:///root/git/vertex_core-12345/': 'git',
        'file:///sdk-path': r'$sdk',
      },
      'mock-test-hash',
      'lean_builder',
    );
  });

  test('PackageFileResolver should resolve package for package uri', () {
    final uri = Uri.parse('package:lean_builder/src/resolvers/package_file_resolver.dart');
    final package = fileResolver.packageFor(uri);
    expect(package, 'lean_builder');
  });

  test('PackageFileResolver should resolve package for package uri', () {
    final uri = Uri.parse('package:git/src/resolvers/package_file_resolver.dart');
    final package = fileResolver.packageFor(uri);
    expect(package, 'git');
  });

  test('PackageFileResolver should resolve path for package', () {
    final path = fileResolver.pathFor('lean_builder');
    expect(path, 'file:///root/lean_builder-1.0.0');
  });

  test('PackageFileResolver should resolve path for package', () {
    final path = fileResolver.pathFor('git');
    expect(path, 'file:///root/git/vertex_core-12345/');
  });

  test('PackageFileResolver should resolve uri for package', () {
    final uri = fileResolver.resolveFileUri(Uri.parse('package:lean_builder/src/resolvers/package_file_resolver.dart'));
    expect(uri, Uri.parse('file:///root/lean_builder-1.0.0/lib/src/resolvers/package_file_resolver.dart'));
  });

  test('PackageFileResolver should resolve relative uri', () {
    final uri = fileResolver.resolveFileUri(
      Uri.parse('file_asset.dart'),
      relativeTo: Uri.parse('file:///root/lean_builder-1.0.0/lib/src/resolvers/package_file_resolver.dart'),
    );
    expect(uri, Uri.parse('file:///root/lean_builder-1.0.0/lib/src/resolvers/file_asset.dart'));
  });

  test('PackageFileResolver should resolve relative uri when back roots', () {
    final uri = fileResolver.resolveFileUri(
      Uri.parse('./file_asset.dart'),
      relativeTo: Uri.parse('file:///root/lean_builder-1.0.0/lib/src/resolvers/'),
    );
    expect(uri, Uri.parse('file:///root/lean_builder-1.0.0/lib/src/file_asset.dart'));
  });

  test('PackageFileResolver should resolve relative uri with leading slash', () {
    final uri = fileResolver.resolveFileUri(
      Uri.parse('/file_asset.dart'),
      relativeTo: Uri.parse('file:///root/lean_builder-1.0.0/lib/src/resolvers/'),
    );
    expect(uri, Uri.parse('file:///root/lean_builder-1.0.0/lib/src/file_asset.dart'));
  });

  test('PackageFileResolver should resolve asset uri', () {
    final uri = fileResolver.resolveFileUri(Uri.parse('asset:lean_builder/test/resolvers/file_asset.dart'));
    expect(uri, Uri.parse('file:///root/lean_builder-1.0.0/test/resolvers/file_asset.dart'));
  });

  test('PackageFileResolver should resolve dart uri', () {
    final uri = fileResolver.resolveFileUri(Uri.parse('dart:core/bool.dart'));
    expect(uri, Uri.parse('file:///sdk-path/lib/core/bool.dart'));
  });

  test('PackageFileResolver should resolve short uri', () {
    final uri = Uri.parse('file:///root/lean_builder-1.0.0/lib/src/resolvers/package_file_resolver.dart');
    final shortUri = fileResolver.toShortUri(uri);
    expect(shortUri, Uri.parse('package:lean_builder/src/resolvers/package_file_resolver.dart'));
  });

  test('PackageFileResolver should resolve short path for asset', () {
    final uri = Uri.parse('file:///root/lean_builder-1.0.0/test/resolvers/file_asset.dart');
    final shortUri = fileResolver.toShortUri(uri);
    expect(shortUri, Uri.parse('asset:lean_builder/test/resolvers/file_asset.dart'));
  });

  test('PackageFileResolver should resolve dart uri for dart:core', () {
    final uri = Uri.parse('file:///sdk-path/lib/core/bool.dart');
    final shortUri = fileResolver.toShortUri(uri);
    expect(shortUri, Uri.parse('dart:core/bool.dart'));
  });

  // test exceptions
  test('PackageFileResolver should throw exception for unknown package', () {
    expect(
      () => fileResolver.packageFor(Uri.parse('package:unknown_package/src/resolvers/package_file_resolver.dart')),
      throwsA(isA<PackageNotFoundError>()),
    );
  });

  test('PackageFileResolver should throw exception for unknown path', () {
    expect(() => fileResolver.pathFor('unknown_package'), throwsA(isA<PackageNotFoundError>()));
  });

  test('Building relative uri without passing a relativeTo uri should throw', () {
    expect(() => fileResolver.buildAssetUri(Uri.parse('path')), throwsA(isA<InvalidPathError>()));
  });

  test('Building asset uri with invalid file path should throw', () {
    expect(() => fileResolver.buildAssetUri(Uri.parse('invalid:io')), throwsA(isA<AssetUriError>()));
  });

  /// non existing package config path should throw
  test('PackageFileResolver should throw exception for non-existing package config path', () {
    expect(() => PackageFileResolverImpl.forRoot('non_existing_path', 'root'), throwsA(isA<PackageConfigLoadError>()));
  });

  /// parsing package config should throw, use this file as package config src
  test('PackageFileResolver should throw exception for invalid package config', () {
    final dir = Directory.current.path;
    final path = '$dir/test/resolvers/package_file_resolver.dart';

    print(File(path).existsSync());
    expect(() => PackageFileResolverImpl.forRoot(path, 'root'), throwsA(isA<PackageConfigParseError>()));
  });
}
