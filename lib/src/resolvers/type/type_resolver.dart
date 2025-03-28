import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:code_genie/src/resolvers/file_asset.dart';
import 'package:code_genie/src/resolvers/package_file_resolver.dart';
import 'package:code_genie/src/resolvers/parsed_units_cache.dart';
import 'package:code_genie/src/resolvers/type/type.dart';
import 'package:code_genie/src/scanner/assets_graph.dart';

class TypeResolver {
  final SrcParser parser;
  final AssetsGraph graph;
  final PackageFileResolver fileResolver;

  TypeResolver(this.parser, this.graph, this.fileResolver);

  DartType resolve(String identifier, AssetSrc asset) {
    throw UnimplementedError();
  }

  InterfaceType resolveInterfaceType(TypeAnnotation annotation, InterfaceElement element) {
    final type = annotation.type;
    if (type is NamedType) {}
    throw UnimplementedError();
  }
}
