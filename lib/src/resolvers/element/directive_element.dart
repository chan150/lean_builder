part of 'element.dart';

abstract class DirectiveElement extends Element {
  Uri get uri;
}

abstract class NamespaceCombinator {}

class ShowElementCombinator implements NamespaceCombinator {
  final List<String> shownNames;

  ShowElementCombinator(this.shownNames);
}

class HideElementCombinator implements NamespaceCombinator {
  final List<String> hiddenNames;

  HideElementCombinator(this.hiddenNames);
}

abstract class ImportElement extends DirectiveElement {
  List<NamespaceCombinator> get combinators;

  bool get isDeferred;

  String? get prefix;
}

abstract class ExportElement extends DirectiveElement {
  List<NamespaceCombinator> get combinators;
}

abstract class PartElement extends DirectiveElement {}

abstract class PartOfElement extends DirectiveElement {}

class ImportElementImpl extends ElementImpl implements ImportElement {
  ImportElementImpl({
    required this.uri,
    required this.library,
    required this.combinators,
    this.isDeferred = false,
    this.prefix,
  });

  @override
  final Uri uri;

  @override
  final LibraryElement library;

  @override
  final List<NamespaceCombinator> combinators;

  @override
  final bool isDeferred;

  @override
  final String? prefix;

  @override
  Element? get enclosingElement => library;

  @override
  String get name => uri.toString();
}

class ExportElementImpl extends ElementImpl implements ExportElement {
  ExportElementImpl({required this.uri, required this.library, required this.combinators});

  @override
  final Uri uri;

  @override
  final LibraryElement library;

  @override
  final List<NamespaceCombinator> combinators;

  @override
  Element? get enclosingElement => library;

  @override
  String get name => uri.toString();
}

class PartElementImpl extends ElementImpl implements PartElement {
  PartElementImpl({required this.uri, required this.library});

  @override
  final Uri uri;

  @override
  final LibraryElement library;

  @override
  Element? get enclosingElement => library;

  @override
  String get name => uri.toString();
}

class PartOfElementImpl extends ElementImpl implements PartOfElement {
  PartOfElementImpl({required this.uri, required this.library});

  @override
  final Uri uri;

  @override
  final LibraryElement library;

  @override
  Element? get enclosingElement => library;

  @override
  String get name => uri.toString();
}
