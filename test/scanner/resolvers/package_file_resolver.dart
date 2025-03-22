import 'package:code_genie/src/resolvers/package_file_resolver.dart';
import 'package:test/test.dart';

void main() {
  late final PackageFileResolverImpl fileResolver;
  setUpAll(() {
    fileResolver = PackageFileResolverImpl(
      {'code_genie': 'file:///root/code_genie-1.0.0'},
      {'file:///root/code_genie-1.0.0': 'code_genie'},
      'mock-test-hash',
      'code_genie',
    );
  });

  test('PackageFileResolver should resolve package for package uri', () {
    final uri = Uri.parse('package:code_genie/src/resolvers/package_file_resolver.dart');
    final package = fileResolver.packageFor(uri);
    expect(package, 'code_genie');
  });

  test('PackageFileResolverImpl should resolve path for package', () {
    final path = fileResolver.pathFor('code_genie');
    expect(path, 'file:///root/code_genie-1.0.0');
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

  test('PackageFileResolver should resolve asset uri', () {
    final uri = fileResolver.resolve(Uri.parse('asset:code_genie/test/resolvers/file_asset.dart'));
    expect(uri, Uri.parse('file:///root/code_genie-1.0.0/test/resolvers/file_asset.dart'));
  });
}
