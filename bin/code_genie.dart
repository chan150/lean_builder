import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:code_genie/src/resolvers/package_file_resolver.dart';
import 'package:code_genie/src/scanner/assets_graph.dart';
import 'package:code_genie/src/scanner/isolate_scanner.dart';
import 'package:code_genie/src/utils.dart';

final packageUrl = '/Users/milad/.pub-cache/hosted/pub.dev/args-2.6.0/lib';
final webPackageUrl = '/Users/milad/.pub-cache/hosted/pub.dev/web-1.1.1/lib';
final autoRoutePackageUrl = '/Users/milad/.pub-cache/hosted/pub.dev/auto_route-10.0.0/lib';
final flutterPackageUrl = '/Users/milad/Dev/sdk/flutter/packages/flutter';
final testPackageUrl = '/Users/milad/StudioProjects/code_genie/lib/test';

void main(List<String> args) async {
  final stopWatch = Stopwatch()..start();
  // if (assetsGraphFile.existsSync()) {
  //   assetsGraphFile.deleteSync(recursive: true);
  // }
  final fileResolver = PackageFileResolver.forCurrentRoot(rootPackageName);
  final AssetsGraph assetsGraph = AssetsGraph.init(fileResolver.packagesHash);
  final isoTlScanner = IsolateTLScanner(assetsGraph: assetsGraph, fileResolver: fileResolver);
  await isoTlScanner.scanAssets();

  // final packageAssets = assetsGraph.getAssetsForPackage(rootPackageName);
  // for (final asset in packageAssets) {
  //   // print(assetsGraph.getIdentifierRef('Container', asset.id));
  //   // if (asset.hasAnnotation && asset.uri.isScheme('package')) {
  //   //
  //   //   final unit = getUnitForAsset(fileResolver, fileAsset.path);
  //   //   final clazz = unit.declarations.whereType<ClassDeclaration>().firstWhere((e) => e.metadata.isNotEmpty);
  //   //   final superClass = clazz.extendsClause!.superclass.name2.lexeme;
  //   //   print(superClass);
  //   //
  //   //   final ref = assetsGraph.getIdentifierRef(superClass, fileAsset.id);
  //   //   if (ref != null) {
  //   //     final superAsset = fileResolver.buildAssetUri(ref.srcUri);
  //   //     final superUnit = getUnitForAsset(fileResolver, superAsset.path);
  //   //     final superClazz = superUnit.declarations.whereType<ClassDeclaration>().firstWhere(
  //   //       (e) => e.name.lexeme == ref.identifier,
  //   //     );
  //   //     print(superClazz);
  //   //     print('src: ${ref.srcUri}');
  //   //     print('provider: ${assetsGraph.assets[ref.providerId]?[0]}');
  //   //   }
  //   // }
  // }

  // for (final asset in packageAssets) {
  //   print(asset);
  // }

  // await assetsGraphFile.writeAsString(jsonEncode(assetsGraph.toJson()));
  print('Time taken: ${stopWatch.elapsed.inMilliseconds} ms');
}

CompilationUnit getUnitForAsset(PackageFileResolver fileResolver, String path) {
  if (_unitsCache.containsKey(path)) {
    return _unitsCache[path]!;
  }
  final unit = parseFile(path: path, featureSet: FeatureSet.latestLanguageVersion()).unit;
  _unitsCache[path] = unit;
  return unit;
}

final _unitsCache = <String, CompilationUnit>{};

// Set<String> resolveIdentifiers(String identifier, ExportsGraph graph) {
//   final source = graph.getSourceForIdentifier(identifier);
//   if (source == null) return {};
//   final CompilationUnit unit;
//   if (_unitsCache.containsKey(source.path)) {
//     unit = _unitsCache[source.path]!;
//   } else {
//     unit = parseFile(path: source.path, featureSet: FeatureSet.latestLanguageVersion()).unit;
//     _unitsCache[source.path] = unit;
//   }
//   final identifierUnit = unit.declarations.whereType<NamedCompilationUnitMember>().firstWhere(
//     (e) => e.name.lexeme == identifier,
//   );
//
//   for (final import in unit.directives.whereType<ImportDirective>()) {
//     final importUri = Uri.parse(import.uri.stringValue!);
//   }
//
//   final identity = <String>{identifier};
//   if (identifierUnit is ClassDeclaration) {
//     if (identifierUnit.extendsClause != null) {
//       final superClass = identifierUnit.extendsClause!.superclass.name2.lexeme;
//       identity.addAll(resolveIdentifiers(superClass, graph));
//     }
//     if (identifierUnit.withClause != null) {
//       for (final mixin in identifierUnit.withClause!.mixinTypes) {
//         final mixinName = mixin.name2.lexeme;
//         identity.addAll(resolveIdentifiers(mixinName, graph));
//       }
//     }
//     if (identifierUnit.implementsClause != null) {
//       for (final impl in identifierUnit.implementsClause!.interfaces) {
//         final implName = impl.name2.lexeme;
//         identity.addAll(resolveIdentifiers(implName, graph));
//       }
//     }
//   }
//
//   return identity;
// }
