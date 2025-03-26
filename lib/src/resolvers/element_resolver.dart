import 'package:analyzer/dart/ast/ast.dart';
import 'package:code_genie/src/resolvers/element.dart';
import 'package:code_genie/src/resolvers/file_asset.dart';
import 'package:code_genie/src/resolvers/package_file_resolver.dart';
import 'package:code_genie/src/resolvers/parsed_units_cache.dart';
import 'package:code_genie/src/resolvers/type/type.dart';
import 'package:code_genie/src/resolvers/type/type_resolver.dart';
import 'package:code_genie/src/resolvers/visitor/element_builder_visitor.dart';
import 'package:code_genie/src/scanner/assets_graph.dart';
import 'package:code_genie/src/scanner/scan_results.dart';

class ElementResolver {
  final AssetsGraph graph;
  final SrcParser parser;
  final PackageFileResolver fileResolver;

  ElementResolver(this.graph, this.fileResolver, this.parser);

  late final _typeResolver = TypeResolver(parser, graph, fileResolver);

  LibraryElement resolveLibrary(AssetFile asset) {
    final unit = parser.parse(asset.path);
    final visitor = ElementBuilderVisitor(this, asset);
    unit.visitChildren(visitor);
    return visitor.libraryElement;
  }

  TypeRef getTypeRef(String identifier, AssetFile asset) {
    throw UnimplementedError();
    // return _typeResolver.resolve(identifier, asset);
  }

  AstNode astNodeFor(String identifier, AssetFile asset) {
    final ref = graph.getIdentifierRef(identifier, asset.id);
    assert(ref != null, 'Identifier $identifier not found in ${asset.uri}');
    final assetFile = fileResolver.buildAssetUri(ref!.srcUri, relativeTo: asset);
    final parsedUnit = parser.parse(assetFile.path);
    if (ref.type == IdentifierType.$class) {
      return parsedUnit.declarations.whereType<ClassDeclaration>().firstWhere(
        (e) => e.name.lexeme == ref.identifier,
        orElse: () => throw Exception('Identifier  ${ref.identifier} not found in ${ref.srcUri}'),
      );
    } else if (ref.type == IdentifierType.$function) {
      return parsedUnit.declarations.whereType<FunctionDeclaration>().firstWhere(
        (e) => e.name.lexeme == ref.identifier,
        orElse: () => throw Exception('Identifier  ${ref.identifier} not found in ${ref.srcUri}'),
      );
    } else if (ref.type == IdentifierType.$variable) {
      return parsedUnit.declarations.whereType<TopLevelVariableDeclaration>().firstWhere(
        (e) => e.variables.variables.first.name.lexeme == ref.identifier,
        orElse: () => throw Exception('Identifier  ${ref.identifier} not found in ${ref.srcUri}'),
      );
    } else {
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
