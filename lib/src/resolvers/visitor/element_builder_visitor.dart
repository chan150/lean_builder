import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:code_genie/src/ast_extensions.dart';
import 'package:code_genie/src/resolvers/element.dart';
import 'package:code_genie/src/resolvers/element_resolver.dart';
import 'package:code_genie/src/resolvers/file_asset.dart';
import 'package:code_genie/src/resolvers/type/type.dart';

class ElementResolverVisitor extends UnifyingAstVisitor<void> {
  final AssetFile src;
  final List<Element> _elementStack = [];
  final ElementResolver resolver;

  Element get _currentElement => _elementStack.last;

  T currentElementAs<T extends Element>() {
    assert(_currentElement is T, 'Current element is not of type $T');
    return _currentElement as T;
  }

  // Push/pop context methods
  void _push(Element element) {
    _elementStack.add(element);
  }

  Element? _pop() {
    if (_elementStack.length > 1) {
      // Always keep library element
      return _elementStack.removeLast();
    }
    return null;
  }

  void _visitScoped(Element element, void Function() callback) {
    if (element == _currentElement) {
      callback();
    }
    _push(element);
    callback();
    _pop();
  }

  ElementResolverVisitor(this.resolver, this.src, LibraryElement rootLibrary) {
    _push(rootLibrary);
  }

  @override
  void visitTypeParameter(TypeParameter node) {
    final element = currentElementAs<TypeParameterizedElementMixin>();
    final bound = node.bound;
    InterfaceType? boundType;
    if (bound != null) {
      boundType = _resolveType(bound, element.library) as InterfaceType;
    }
    element.addTypeParameter(TypeParameterElement(element, node.name.lexeme, boundType));
  }

  @override
  void visitTypeArgumentList(TypeArgumentList node) {}

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final libraryElement = currentElementAs<LibraryElement>();
    final ClassElementImpl classElement;
    if (libraryElement.getClass(node.name.lexeme) != null) {
      classElement = libraryElement.getClass(node.name.lexeme)!;
    } else {
      classElement = ClassElementImpl(name: node.name.lexeme, library: libraryElement);
      libraryElement.resolvedElements.add(classElement);
    }
    _visitScoped(classElement, () {
      node.typeParameters?.visitChildren(this);
      for (final field in node.fields) {
        field.accept(this);
      }
    });

    final superType = node.extendsClause?.superclass;
    if (superType != null) {
      final resolvedSuperType = _resolveType(superType, libraryElement);
      assert(resolvedSuperType is InterfaceType, 'Super type must be an interface type');
      classElement.superType = resolvedSuperType as InterfaceType;
    }

    for (final mixin in [...?node.withClause?.mixinTypes]) {
      final mixinType = _resolveType(mixin, libraryElement);
      assert(mixinType is InterfaceType, 'Mixin type must be an interface type');
      classElement.addMixin(mixinType as InterfaceType);
    }

    for (final interface in [...?node.implementsClause?.interfaces]) {
      final interfaceType = _resolveType(interface, libraryElement);
      assert(interfaceType is InterfaceType, 'Interface type must be an interface type');
      classElement.addInterface(interfaceType as InterfaceType);
    }
  }

  InterfaceElement _resolveInterfaceElement(String typename, LibraryElement enclosingLibrary) {
    final (library, decNode) = resolver.astNodeFor(typename, enclosingLibrary);
    InterfaceElement? decEle = library.getInterfaceElement(typename);
    if (decEle != null) {
      return decEle;
    }
    _visitScoped(library, () => decNode.accept(this));
    decEle = library.getInterfaceElement(typename);
    assert(decEle != null, 'Super type $typename could not be resolved');
    return decEle!;
  }

  DartType _resolveType(TypeAnnotation? typeAnno, LibraryElement enclosingLibrary) {
    if (typeAnno == null) {
      return NeverType();
    }
    if (typeAnno is NamedType) {
      final typename = typeAnno.name;
      if (typename == null) {
        return NeverType();
      }
      final element = _resolveInterfaceElement(typename, enclosingLibrary);
      final typeArgsAnnotations = typeAnno.typeArguments?.arguments.toList();
      if (typeArgsAnnotations != null) {
        // final typeArgs = typeArgsAnnotations.map((e) => _resolveType(e, element.library)).toList();
        // return InterfaceTypeImpl(name: typename, element: element, typeArguments: typeArgs);
      }
      return InterfaceTypeImpl(name: typename, element: element);
    }
    return NeverType();
    //
    // throw UnimplementedError('Type annotation not supported: $typeAnno');
  }

  @override
  void visitFieldDeclaration(FieldDeclaration node) {
    final interfaceElement = currentElementAs<InterfaceElementImpl>();
    final fieldType = _resolveType(node.type, interfaceElement.library);
    // Process each variable in the field declaration
    for (final variable in node.fields.variables) {
      final field = FieldElement(
        isStatic: node.isStatic,
        name: variable.name.lexeme,
        isAbstract: node.abstractKeyword != null,
        library: interfaceElement.library,
        isCovariant: node.covariantKeyword != null,
        isEnumConstant: false,
        isExternal: node.externalKeyword != null,
        enclosingElement: interfaceElement,
        hasImplicitType: node.fields.type == null,
        isConst: node.fields.isConst,
        isFinal: node.fields.isFinal,
        isLate: node.fields.isLate,
        type: fieldType,
      );
      interfaceElement.addField(field);
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
    // print('visiting method declaration: ${node.name.lexeme}');
    // final classElement = currentElementAs<ClassElement>();
    // final method = MethodElement(
    //   isStatic: node.isStatic,
    //   name: node.name.lexeme,
    //   library: classElement.library,
    //   enclosingElement: classElement,
    //   returnType: TypeRef('name', src.id),
    // );
    // classElement.methods.add(method);
    // _push(method);
    // for (final parameter in node.parameters!.parameters) {
    //   parameter.accept(this);
    // }
    // _pop();
  }

  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) {
    print('visiting constructor declaration: ${node.name?.lexeme}');
  }
}
