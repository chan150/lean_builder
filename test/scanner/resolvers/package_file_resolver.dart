import 'package:code_genie/src/resolvers/package_file_resolver.dart';
import 'package:test/test.dart';

void main() {
  late final PackageFileResolverImpl fileResolver;
  setUpAll(() {
    fileResolver = PackageFileResolverImpl(
      {
        'code_genie': 'file:///root/code_genie-1.0.0',
        'git': 'file:///root/git/vertex_core-12345/',
        PackageFileResolverImpl.dartSdk: PackageFileResolverImpl.dartSdkPath.toString(),
      },
      {
        'file:///root/code_genie-1.0.0': 'code_genie',
        'file:///root/git/vertex_core-12345/': 'git',
        PackageFileResolverImpl.dartSdkPath.toString(): PackageFileResolverImpl.dartSdk,
      },
      'mock-test-hash',
      'code_genie',
    );
  });

  test('PackageFileResolver should resolve package for package uri', () {
    final uri = Uri.parse('package:code_genie/src/resolvers/package_file_resolver.dart');
    final package = fileResolver.packageFor(uri);
    expect(package, 'code_genie');
  });

  test('PackageFileResolver should resolve package for package uri', () {
    final uri = Uri.parse('package:git/src/resolvers/package_file_resolver.dart');
    final package = fileResolver.packageFor(uri);
    expect(package, 'git');
  });

  test('PackageFileResolver should resolve path for package', () {
    final path = fileResolver.pathFor('code_genie');
    expect(path, 'file:///root/code_genie-1.0.0');
  });

  test('PackageFileResolver should resolve path for package', () {
    final path = fileResolver.pathFor('git');
    expect(path, 'file:///root/git/vertex_core-12345/');
  });

  test('PackageFileResolver should resolve uri for package', () {
    final uri = fileResolver.resolve(Uri.parse('package:code_genie/src/resolvers/package_file_resolver.dart'));
    expect(uri, Uri.parse('file:///root/code_genie-1.0.0/lib/src/resolvers/package_file_resolver.dart'));
  });

  test('PackageFileResolver should resolve relative uri', () {
    final uri = fileResolver.resolve(
      Uri.parse('file_asset.dart'),
      relativeTo: Uri.parse('file:///root/code_genie-1.0.0/lib/src/resolvers/package_file_resolver.dart'),
    );
    expect(uri, Uri.parse('file:///root/code_genie-1.0.0/lib/src/resolvers/file_asset.dart'));
  });

  test('PackageFileResolver should resolve relative uri when back roots', () {
    final uri = fileResolver.resolve(
      Uri.parse('./file_asset.dart'),
      relativeTo: Uri.parse('file:///root/code_genie-1.0.0/lib/src/resolvers/'),
    );
    expect(uri, Uri.parse('file:///root/code_genie-1.0.0/lib/src/file_asset.dart'));
  });

  test('PackageFileResolver should resolve relative uri with leading slash', () {
    final uri = fileResolver.resolve(
      Uri.parse('/file_asset.dart'),
      relativeTo: Uri.parse('file:///root/code_genie-1.0.0/lib/src/resolvers/'),
    );
    expect(uri, Uri.parse('file:///root/code_genie-1.0.0/lib/src/file_asset.dart'));
  });

  test('PackageFileResolver should resolve asset uri', () {
    final uri = fileResolver.resolve(Uri.parse('asset:code_genie/test/resolvers/file_asset.dart'));
    expect(uri, Uri.parse('file:///root/code_genie-1.0.0/test/resolvers/file_asset.dart'));
  });

  // resolve dart library
  test('PackageFileResolver should resolve dart uri', () {
    final uri = fileResolver.resolve(Uri.parse('dart:core'));
    expect(uri, Uri.parse('${PackageFileResolverImpl.dartSdkPath}/lib/core/core.dart'));
  });

  // test to shortPath
  test('PackageFileResolver should resolve short path', () {
    final uri = Uri.parse('file:///root/code_genie-1.0.0/lib/src/resolvers/package_file_resolver.dart');
    final shortPath = fileResolver.toShortPath(uri);
    expect(shortPath, Uri.parse('package:code_genie/src/resolvers/package_file_resolver.dart'));
  });

  // test to shortPath asset
  test('PackageFileResolver should resolve short path for asset', () {
    final uri = Uri.parse('file:///root/code_genie-1.0.0/test/resolvers/file_asset.dart');
    final shortPath = fileResolver.toShortPath(uri);
    expect(shortPath, Uri.parse('asset:code_genie/test/resolvers/file_asset.dart'));
  });

  // dart:core
  test('PackageFileResolver should resolve dart uri for dart:core', () {
    final uri = Uri.parse('${PackageFileResolverImpl.dartSdkPath}/lib/core/core.dart');
    final shortPath = fileResolver.toShortPath(uri);
    expect(shortPath, Uri.parse('dart:core'));
  });
}
