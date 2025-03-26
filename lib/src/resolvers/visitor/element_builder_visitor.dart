import 'package:analyzer/dart/ast/ast.dart';
import 'package:code_genie/src/ast_extensions.dart';
import 'package:code_genie/src/resolvers/element.dart';
import 'package:code_genie/src/resolvers/element_resolver.dart';
import 'package:code_genie/src/resolvers/file_asset.dart';
import 'package:code_genie/src/resolvers/type/type.dart';
import 'package:code_genie/src/resolvers/visitor/visitor.dart';

class ElementBuilderVisitor extends IgnoringAstVisitor<void> {
  final AssetFile src;
  final List<Element> topLevelElements = [];
  late final LibraryElement libraryElement;
  final List<Element> _elementStack = [];
  final ElementResolver resolver;

  Element get currentElement => _elementStack.last;

  T currentElementAs<T extends Element>() {
    assert(currentElement is T, 'Current element is not of type $T');
    return currentElement as T;
  }

  // Push/pop context methods
  void _pushContext(Element element) {
    _elementStack.add(element);
  }

  void _popContext() {
    if (_elementStack.length > 1) {
      // Always keep library element
      _elementStack.removeLast();
    }
  }

  ElementBuilderVisitor(this.resolver, this.src) {
    final name = src.shortPath.path.split('/').lastOrNull ?? 'unknown';
    libraryElement = LibraryElement(name: name, srcId: src.id, topLevelElements: topLevelElements);
    _pushContext(libraryElement);
  }

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    print('visiting class declaration: ${node.name.lexeme}');
    final classElement = ClassElement(name: node.name.lexeme, library: libraryElement);

    topLevelElements.add(classElement);
    _pushContext(classElement);
    for (var member in node.members) {
      member.accept(this);
    }
    _popContext();
  }

  @override
  void visitFieldDeclaration(FieldDeclaration node) {
    final classElement = currentElementAs<ClassElement>();
    // Process each variable in the field declaration

    if (node.type != null) {
      final typeNode = resolver.astNodeFor(node.type!.name!, src);
      typeNode.accept(this);
    }

    for (final variable in node.fields.variables) {
      final field = FieldElement(
        isStatic: node.isStatic,
        name: variable.name.lexeme,
        isAbstract: node.abstractKeyword != null,
        library: libraryElement,
        isCovariant: node.covariantKeyword != null,
        isEnumConstant: false,
        isExternal: node.externalKeyword != null,
        enclosingElement: classElement,
        hasImplicitType: node.fields.type == null,
        isConst: node.fields.isConst,
        isFinal: node.fields.isFinal,
        isLate: node.fields.isLate,
        type: TypeRef('name', src.id),
      );
      classElement.fields.add(field);
    }
  }

  // visit method
  @override
  void visitCompilationUnit(CompilationUnit node) {
    print('visiting compilation unit');
    for (final declaration in node.declarations) {
      declaration.accept(this);
    }
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    print('visiting method declaration: ${node.name.lexeme}');
    final classElement = currentElementAs<ClassElement>();
    final method = MethodElement(
      isStatic: node.isStatic,
      name: node.name.lexeme,
      library: libraryElement,
      enclosingElement: classElement,
      returnType: TypeRef('name', src.id),
    );
    classElement.methods.add(method);
    _pushContext(method);
    for (final parameter in node.parameters!.parameters) {
      parameter.accept(this);
    }
    _popContext();
  }

  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) {
    print('visiting constructor declaration: ${node.name?.lexeme}');
  }

  @override
  void visitTypeAnnotation(TypeAnnotation node) {
    print('visiting type annotation: ${node.toString()}');
  }
}
