import 'package:analyzer/dart/ast/ast.dart';
import 'package:code_genie/src/resolvers/element/element.dart';
import 'package:code_genie/src/resolvers/file_asset.dart';
import 'package:code_genie/src/resolvers/package_file_resolver.dart';
import 'package:code_genie/src/resolvers/parsed_units_cache.dart';
import 'package:code_genie/src/resolvers/type/type_resolver.dart';
import 'package:code_genie/src/resolvers/visitor/element_builder_visitor.dart';
import 'package:code_genie/src/scanner/assets_graph.dart';
import 'package:code_genie/src/scanner/scan_results.dart';

class ElementResolver {
  final AssetsGraph graph;
  final SrcParser parser;
  final PackageFileResolver fileResolver;
  final Map<String, LibraryElement> _libraryCache = {};

  ElementResolver(this.graph, this.fileResolver, this.parser);

  late final _typeResolver = TypeResolver(parser, graph, fileResolver);

  LibraryElement resolveLibrary(AssetSrc src) {
    final unit = parser.parse(src.path);
    final rootLibrary = libraryFor(src);
    final visitor = ElementResolverVisitor(this, src, rootLibrary);
    unit.visitChildren(visitor);
    return rootLibrary;
  }

  LibraryElement libraryFor(AssetSrc src) {
    return _libraryCache.putIfAbsent(src.id, () {
      final name = src.uri.pathSegments.last;
      return LibraryElementImpl(name: name, src: src);
    });
  }

  (LibraryElement, AstNode) astNodeFor(String identifier, LibraryElement enclosingLibrary) {
    final enclosingAsset = enclosingLibrary.src;
    final ref = graph.getIdentifierRef(identifier, enclosingAsset.id, requireProvider: false);
    assert(ref != null, 'Identifier $identifier not found in ${enclosingAsset.uri}');
    final assetFile = fileResolver.buildAssetUri(ref!.srcUri, relativeTo: enclosingAsset);

    final library = libraryFor(assetFile);
    final parsedUnit = parser.parse(assetFile.path);
    if (ref.type == IdentifierType.$class) {
      final unit = parsedUnit.declarations.whereType<ClassDeclaration>().firstWhere(
        (e) => e.name.lexeme == ref.identifier,
        orElse: () => throw Exception('Identifier  ${ref.identifier} not found in ${ref.srcUri}'),
      );
      return (library, unit);
    } else if (ref.type == IdentifierType.$extension) {
      final unit = parsedUnit.declarations.whereType<ExtensionDeclaration>().firstWhere(
        (e) => e.name?.lexeme == ref.identifier,
        orElse: () => throw Exception('Identifier  ${ref.identifier} not found in ${ref.srcUri}'),
      );
      return (library, unit);
    } else if (ref.type == IdentifierType.$mixin) {
      final unit = parsedUnit.declarations.whereType<MixinDeclaration>().firstWhere(
        (e) => e.name.lexeme == ref.identifier,
        orElse: () => throw Exception('Identifier  ${ref.identifier} not found in ${ref.srcUri}'),
      );
      return (library, unit);
    } else if (ref.type == IdentifierType.$enum) {
      final unit = parsedUnit.declarations.whereType<EnumDeclaration>().firstWhere(
        (e) => e.name.lexeme == ref.identifier,
        orElse: () => throw Exception('Identifier  ${ref.identifier} not found in ${ref.srcUri}'),
      );
      return (library, unit);
    } else if (ref.type == IdentifierType.$typeAlias) {
      final unit = parsedUnit.declarations.whereType<TypeAlias>().firstWhere(
        (e) => e.name.lexeme == ref.identifier,
        orElse: () => throw Exception('Identifier  ${ref.identifier} not found in ${ref.srcUri}'),
      );
      return (library, unit);
    } else if (ref.type == IdentifierType.$function) {
      final unit = parsedUnit.declarations.whereType<FunctionDeclaration>().firstWhere(
        (e) => e.name.lexeme == ref.identifier,
        orElse: () => throw Exception('Identifier  ${ref.identifier} not found in ${ref.srcUri}'),
      );
      return (library, unit);
    } else if (ref.type == IdentifierType.$variable) {
      final unit = parsedUnit.declarations.whereType<TopLevelVariableDeclaration>().firstWhere(
        (e) => e.variables.variables.first.name.lexeme == ref.identifier,
        orElse: () => throw Exception('Identifier  ${ref.identifier} not found in ${ref.srcUri}'),
      );
      return (library, unit);
    } else {
      print('Unknown identifier type: ${ref.type}');
      throw UnimplementedError();
    }
  }

  // Element resolve(IdentifierRef ref) {
  //
  //
  //   final asset = fileResolver.buildAssetUri(ref.srcUri);
  //   final unit = parser.parse(asset.path);
  //
  //   final namedUnit = unit.declarations.whereType<NamedCompilationUnitMember>().firstWhere(
  //     (e) => e.name.lexeme == ref.identifier,
  //     orElse: () => throw Exception('Identifier  ${ref.identifier} not found in ${ref.srcUri}'),
  //   );
  //
  //
  // }
}
