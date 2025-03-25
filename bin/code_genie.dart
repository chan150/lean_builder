import 'dart:async';

import 'package:code_genie/src/resolvers/package_file_resolver.dart';
import 'package:code_genie/src/scanner/assets_graph.dart';
import 'package:code_genie/src/scanner/isolate_scanner.dart';
import 'package:code_genie/src/utils.dart';

final testFile = '/Users/milad/StudioProjects/code_genie/lib/test/test.dart';

void main(List<String> args) async {
  Future;
  final stopWatch = Stopwatch()..start();
  print('Running Fresh Version');
  if (AssetsGraph.cacheFile.existsSync()) {
    AssetsGraph.cacheFile.deleteSync(recursive: true);
  }
  final fileResolver = PackageFileResolver.forCurrentRoot(rootPackageName);
  final AssetsGraph assetsGraph = AssetsGraph.init(fileResolver.packagesHash);
  // final scanner = TopLevelScanner(assetsGraph, fileResolver);
  // final asset = fileResolver.buildAssetUri(Uri.parse('package:code_genie/test/test.dart'));

  // scanner.scanFile(asset);
  // AssetsGraph.cacheFile.writeAsString(jsonEncode(assetsGraph.toJson()));

  final isoTlScanner = IsolateTLScanner(assetsGraph: assetsGraph, fileResolver: fileResolver);
  await isoTlScanner.scanAssets();

  final id = assetsGraph.getIdentifierRef('bool', '');
  print(id);
  // final parser = SrcParser();
  // final resolver = ElementResolver(assetsGraph, fileResolver, parser);
  // final packageAssets = assetsGraph.getAssetsForPackage(rootPackageName);
  //
  // for (final asset in packageAssets) {
  //   // print(assetsGraph.getIdentifierRef('Container', asset.id));
  //   if (asset.hasAnnotation) {
  //     final assetFile = fileResolver.buildAssetUri(asset.uri);
  //     final library = resolver.resolveLibrary(assetFile);
  //
  //     for (final clazz in library.classes) {
  //       print(clazz.name);
  //       print(clazz.fields.map((e) => e.name));
  //       print(clazz.methods.map((e) => e.name));
  //     }
  //
  //     // final unit = parser.parse(assetFile.path);
  //     // final clazz = unit.declarations.whereType<ClassDeclaration>().firstWhere((e) => e.metadata.isNotEmpty);
  //     // final annotation = clazz.metadata.first;
  //     // final annotationIdRef = assetsGraph.getIdentifierRef(annotation.name.name, assetFile.id)!;
  //     // final type = resolver.resolve(annotationIdRef);
  //     // print(type);
  //
  //     //
  //     //   final unit = getUnitForAsset(fileResolver, fileAsset.path);
  //     //   final clazz = unit.declarations.whereType<ClassDeclaration>().firstWhere((e) => e.metadata.isNotEmpty);
  //     //   final superClass = clazz.extendsClause!.superclass.name2.lexeme;
  //     //   print(superClass);
  //     //
  //     //   final ref = assetsGraph.getIdentifierRef(superClass, fileAsset.id);
  //     //   if (ref != null) {
  //     //     final superAsset = fileResolver.buildAssetUri(ref.srcUri);
  //     //     final superUnit = getUnitForAsset(fileResolver, superAsset.path);
  //     //     final superClazz = superUnit.declarations.whereType<ClassDeclaration>().firstWhere(
  //     //       (e) => e.name.lexeme == ref.identifier,
  //     //     );
  //     //     print(superClazz);
  //     //     print('src: ${ref.srcUri}');
  //     //     print('provider: ${assetsGraph.assets[ref.providerId]?[0]}');
  //     //   }
  //   }
  // }

  // await assetsGraphFile.writeAsString(jsonEncode(assetsGraph.toJson()));
  print('Time taken: ${stopWatch.elapsed.inMilliseconds} ms');
}

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
