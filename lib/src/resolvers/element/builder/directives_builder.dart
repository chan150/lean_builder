import 'package:analyzer/dart/ast/ast.dart';
import 'package:lean_builder/src/resolvers/element/builder/element_builder.dart';
import 'package:lean_builder/src/resolvers/element/element.dart';
import 'package:lean_builder/src/scanner/directive_statement.dart';
import 'package:lean_builder/src/scanner/scan_results.dart';

class DirectivesBuilder extends ElementBuilder {
  DirectivesBuilder(super.resolver, super.rootLibrary);

  @override
  void visitImportDirective(ImportDirective node) {
    final stringUri = node.uri.stringValue;
    if (stringUri == null) return;
    final library = currentLibrary();
    final directive = _getCorrespondingDirective(library, stringUri, DirectiveStatement.import);
    final showNames = <String>[];
    final hideNames = <String>[];
    for (final comb in node.combinators) {
      if (comb is ShowCombinator) {
        showNames.addAll(comb.shownNames.map((e) => e.name));
      } else if (comb is HideCombinator) {
        hideNames.addAll(comb.hiddenNames.map((e) => e.name));
      }
    }

    final element = ImportElement(
      library: library,
      stringUri: stringUri,
      srcId: directive[GraphIndex.directiveSrc],
      uri: resolver.uriForAsset(directive[GraphIndex.directiveSrc]),
      shownNames: showNames,
      hiddenNames: hideNames,
      prefix: node.prefix?.name,
      isDeferred: node.deferredKeyword != null,
    );

    visitElementScoped(element, () {
      node.documentationComment?.accept(this);
    });

    library.addElement(element);
    registerMetadataResolver(element, node.metadata);
  }

  @override
  void visitExportDirective(ExportDirective node) {
    final stringUri = node.uri.stringValue;
    if (stringUri == null) return;
    final library = currentLibrary();
    final directive = _getCorrespondingDirective(library, stringUri, DirectiveStatement.export);
    final showNames = <String>[];
    final hideNames = <String>[];
    for (final comb in node.combinators) {
      if (comb is ShowCombinator) {
        showNames.addAll(comb.shownNames.map((e) => e.name));
      } else if (comb is HideCombinator) {
        hideNames.addAll(comb.hiddenNames.map((e) => e.name));
      }
    }

    final element = ExportElement(
      library: library,
      stringUri: stringUri,
      srcId: directive[GraphIndex.directiveSrc],
      uri: resolver.uriForAsset(directive[GraphIndex.directiveSrc]),
      shownNames: showNames,
      hiddenNames: hideNames,
    );

    visitElementScoped(element, () {
      node.documentationComment?.accept(this);
    });

    library.addElement(element);
    registerMetadataResolver(element, node.metadata);
  }

  @override
  void visitPartDirective(PartDirective node) {
    final stringUri = node.uri.stringValue;
    if (stringUri == null) return;
    final library = currentLibrary();
    final directive = _getCorrespondingDirective(library, stringUri, DirectiveStatement.part);
    final element = PartElement(
      library: library,
      stringUri: stringUri,
      srcId: directive[GraphIndex.directiveSrc],
      uri: resolver.uriForAsset(directive[GraphIndex.directiveSrc]),
    );

    visitElementScoped(element, () {
      node.documentationComment?.accept(this);
    });

    library.addElement(element);
    registerMetadataResolver(element, node.metadata);
  }

  @override
  void visitPartOfDirective(PartOfDirective node) {
    final stringUri = node.uri?.stringValue;
    if (stringUri == null) return;
    final library = currentLibrary();
    final thisSrc = library.src.id;
    final partOf = resolver.graph.partOfOf(thisSrc);
    assert(partOf != null && partOf[GraphIndex.directiveStringUri] == stringUri);
    final actualSrc = partOf![GraphIndex.directiveSrc];
    final element = PartOfElement(
      referencesLibraryDirective: true,
      uri: resolver.uriForAsset(actualSrc),
      library: library,
      srcId: actualSrc,
      stringUri: stringUri,
    );
    visitElementScoped(element, () {
      node.documentationComment?.accept(this);
    });
    library.addElement(element);
    registerMetadataResolver(element, node.metadata);
  }

  @override
  void visitLibraryDirective(LibraryDirective node) {
    final name = node.name2?.name;
    if (name == null) return;
    final library = currentLibrary();
    final asset = resolver.graph.assets[library.src.id];
    assert(
      asset?.elementAtOrNull(GraphIndex.assetLibraryName) == name,
      'Library name mismatch: ${asset?.elementAtOrNull(GraphIndex.assetLibraryName)} != $name',
    );
    final element = LibraryDirectiveElement(
      library: library,
      stringUri: name,
      srcId: library.src.id,
      uri: resolver.uriForAsset(library.src.id),
    );
    visitElementScoped(element, () {
      node.documentationComment?.accept(this);
    });
    library.addElement(element);
    registerMetadataResolver(element, node.metadata);
  }

  List<dynamic> _getCorrespondingDirective(LibraryElementImpl library, String stringUri, int type) {
    final fileDirectives = resolver.graph.directives[library.src.id];
    if (fileDirectives == null) {
      throw StateError('No directives found for ${library.src.shortUri}');
    }
    final directive = fileDirectives.firstWhere(
      (element) => element[GraphIndex.directiveStringUri] == stringUri && element[GraphIndex.directiveType] == type,
      orElse: () => throw StateError('No export directive found for $stringUri in ${library.src.shortUri}'),
    );
    return directive;
  }
}
