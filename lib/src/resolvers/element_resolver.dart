import 'package:code_genie/src/resolvers/element.dart';
import 'package:code_genie/src/resolvers/file_asset.dart';
import 'package:code_genie/src/resolvers/package_file_resolver.dart';
import 'package:code_genie/src/resolvers/parsed_units_cache.dart';
import 'package:code_genie/src/resolvers/type/type.dart';
import 'package:code_genie/src/resolvers/type/type_resolver.dart';
import 'package:code_genie/src/resolvers/visitor/element_builder_visitor.dart';
import 'package:code_genie/src/scanner/assets_graph.dart';

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
