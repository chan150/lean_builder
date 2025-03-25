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

  DartType resolve(String identifier, AssetFile asset) {
    throw UnimplementedError();
  }
}
