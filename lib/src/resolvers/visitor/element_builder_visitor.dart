import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:code_genie/src/ast_extensions.dart';
import 'package:code_genie/src/resolvers/const/const_evaluator.dart';
import 'package:code_genie/src/resolvers/element/element.dart';
import 'package:code_genie/src/resolvers/element/element_annotation.dart';
import 'package:code_genie/src/resolvers/element_resolver.dart';
import 'package:code_genie/src/resolvers/type/type.dart';
import 'package:code_genie/src/resolvers/visitor/element_stack.dart';

class ElementResolverVisitor extends UnifyingAstVisitor<void> with ElementStack {
  final ElementResolver _resolver;

  ElementResolverVisitor(this._resolver, LibraryElement rootLibrary) {
    pushElement(rootLibrary);
  }

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final libraryElement = currentElementAs<LibraryElement>();
    if (libraryElement.getClass(node.name.lexeme) != null) {
      return;
    }
    final classElement = ClassElementImpl(name: node.name.lexeme, library: libraryElement);
    libraryElement.resolvedElements.add(classElement);
    classElement.thisType = InterfaceTypeImpl(classElement);

    visitElementScoped(classElement, () {
      node.typeParameters?.visitChildren(this);
      for (final field in node.fields) {
        field.accept(this);
      }
    });

    final superType = node.extendsClause?.superclass;
    if (superType != null) {
      final resolvedSuperType = _resolveType(superType, classElement, classElement.typeParameters);
      assert(resolvedSuperType is InterfaceType, 'Super type must be an interface type');
      classElement.superType = resolvedSuperType as InterfaceType;
    }

    for (final mixin in [...?node.withClause?.mixinTypes]) {
      final mixinType = _resolveType(mixin, classElement, classElement.typeParameters);
      assert(mixinType is InterfaceType, 'Mixin type must be an interface type');
      classElement.addMixin(mixinType as InterfaceType);
    }

    for (final interface in [...?node.implementsClause?.interfaces]) {
      final interfaceType = _resolveType(interface, classElement, classElement.typeParameters);
      assert(interfaceType is InterfaceType, 'Interface type must be an interface type');
      classElement.addInterface(interfaceType as InterfaceType);
    }
  }

  @override
  void visitMixinDeclaration(MixinDeclaration node) {
    final libraryElement = currentElementAs<LibraryElement>();
    final MixinElementImpl mixinElement;
    if (libraryElement.getMixin(node.name.lexeme) != null) {
      return;
    } else {
      mixinElement = MixinElementImpl(name: node.name.lexeme, library: libraryElement);
      libraryElement.resolvedElements.add(mixinElement);
    }
    mixinElement.thisType = InterfaceTypeImpl(mixinElement);

    visitElementScoped(mixinElement, () {
      node.typeParameters?.visitChildren(this);
    });

    for (final interface in [...?node.implementsClause?.interfaces]) {
      final interfaceType = _resolveType(interface, mixinElement, mixinElement.typeParameters);
      assert(interfaceType is InterfaceType, 'Interface type must be an interface type');
      mixinElement.addInterface(interfaceType as InterfaceType);
    }

    for (final on in [...?node.onClause?.superclassConstraints]) {
      final onType = _resolveType(on, mixinElement, mixinElement.typeParameters);
      assert(onType is InterfaceType, 'On type must be an interface type');
      mixinElement.addSuperConstrain(onType as InterfaceType);
    }
  }

  @override
  void visitEnumDeclaration(EnumDeclaration node) {
    final libraryElement = currentElementAs<LibraryElement>();
    final EnumElementImpl enumElement;
    if (libraryElement.getEnum(node.name.lexeme) != null) {
      return;
    } else {
      enumElement = EnumElementImpl(name: node.name.lexeme, library: libraryElement);
      libraryElement.resolvedElements.add(enumElement);
    }
    enumElement.thisType = InterfaceTypeImpl(enumElement);
    visitElementScoped(enumElement, () {
      for (final constant in node.constants) {
        final constantName = constant.name.lexeme;
        final fieldEle = FieldElementImpl(
          isStatic: true,
          name: constantName,
          isAbstract: false,
          library: enumElement.library,
          isCovariant: false,
          isEnumConstant: true,
          enclosingElement: enumElement,
          hasImplicitType: false,
          isConst: true,
          isFinal: true,
          isLate: false,
          isExternal: false,
          type: enumElement.thisType,
        );
        enumElement.addField(fieldEle);
      }
    });
  }

  @override
  void visitTypeParameter(TypeParameter node) {
    final element = currentElementAs<TypeParameterizedElementMixin>();
    final bound = node.bound;
    InterfaceType? boundType;
    if (bound != null) {
      boundType = _resolveType(bound, element, []) as InterfaceType;
    }
    element.addTypeParameter(TypeParameterElementImpl(element, node.name.lexeme, boundType));
  }

  @override
  void visitFunctionTypeAlias(FunctionTypeAlias node) {
    final libraryElement = currentElementAs<LibraryElement>();

    // final FunctionTypeAliasElementImpl functionTypeAliasElement;
    // if (libraryElement.getFunctionTypeAlias(node.name.lexeme) != null) {
    //   return;
    // } else {
    //   functionTypeAliasElement = FunctionTypeAliasElementImpl(name: node.name.lexeme, library: libraryElement);
    //   libraryElement.resolvedElements.add(functionTypeAliasElement);
    // }
    // functionTypeAliasElement.thisType = InterfaceTypeImpl(name: functionTypeAliasElement.name, element: functionTypeAliasElement);
    //
    // _visitScoped(functionTypeAliasElement, () {
    //   node.typeParameters?.visitChildren(this);
    //   for (final parameter in node.parameters.parameters) {
    //     parameter.accept(this);
    //   }
    // });
  }

  Element _resolveElement(String typename, LibraryElement enclosingLibrary) {
    final (library, decNode) = _resolver.astNodeFor(typename, enclosingLibrary);
    Element? decEle = library.getElement(typename);
    if (decEle != null) {
      return decEle;
    }
    visitElementScoped(library, () => decNode.accept(this));
    decEle = library.getElement(typename);
    assert(decEle != null, 'Super type $typename could not be resolved ${library.src.uri}');
    return decEle!;
  }

  DartType _resolveType(
    TypeAnnotation? typeAnno,
    Element enclosingEle, [
    List<TypeParameterElement> typeParams = const [],
  ]) {
    for (final typeParam in typeParams) {
      if (typeParam.name == typeAnno?.name) {
        return TypeParameterType(typeParam, typeParam.bound ?? DynamicType());
      }
    }

    if (typeAnno is NamedType) {
      return _resolveNamedType(typeAnno, enclosingEle, typeParams);
    } else if (typeAnno is GenericFunctionType) {
      return _resolveFunctionType(typeAnno, FunctionElementImpl(name: '', library: enclosingEle.library), typeParams);
    }
    return NeverType();
  }

  FunctionType _resolveFunctionType(
    GenericFunctionType typeAnno,
    FunctionElement funcElement,
    List<TypeParameterElement> typeParams,
  ) {
    visitElementScoped(funcElement, () {
      typeAnno.typeParameters?.visitChildren(this);
      typeAnno.parameters.visitChildren(this);
    });
    final returnType = _resolveType(typeAnno.returnType, funcElement, [...typeParams, ...funcElement.typeParameters]);
    return FunctionTypeImpl(
      name: funcElement.name,
      returnType: returnType,
      typeParameters: funcElement.typeParameters,
      parameters: funcElement.parameters,
    );
  }

  DartType _resolveNamedType(NamedType typeAnno, Element enclosingEle, List<TypeParameterElement> typeParams) {
    final typename = typeAnno.name;
    if (typename == null) {
      return DartType.neverType;
    }
    if (typename == 'void') {
      return DartType.voidType;
    }
    if (typename == 'dynamic') {
      return DartType.dynamicType;
    }

    final element = _resolveElement(typename, enclosingEle.library) as InterfaceElement;
    final typeArgs = <DartType>[];
    for (final typeArg in [...?typeAnno.typeArguments?.arguments]) {
      typeArgs.add(_resolveType(typeArg, enclosingEle, typeParams));
    }

    return InterfaceTypeImpl(element, typeArgs);
  }

  @override
  void visitFieldDeclaration(FieldDeclaration node) {
    final interfaceElement = currentElementAs<InterfaceElementImpl>();
    final fieldType = _resolveType(node.type, interfaceElement, interfaceElement.typeParameters);
    // Process each variable in the field declaration
    for (final variable in node.fields.variables) {
      final fieldEle = FieldElementImpl(
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

      // final constVisitor = ConstantEvaluator();
      // final constantValue = variable.initializer?.accept(constVisitor);
      // print('${fieldEle.name}: ${constantValue}');
      interfaceElement.addField(fieldEle);
    }
  }

  @override
  void visitAnnotation(Annotation node) {
    final element = currentElementAs<ElementImpl>();
    final typeArgs = <DartType>[];
    for (final typeArg in [...?node.typeArguments?.arguments]) {
      typeArgs.add(_resolveType(typeArg, element, []));
    }
    final elementAnnotation = ElementAnnotationImpl(node.name.name, element);

    // final type = _resolveType(node, element, typeParams)
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    final libraryElement = currentElementAs<LibraryElement>();
    if (libraryElement.getFunction(node.name.lexeme) != null) {
      return;
    }
    final body = node.functionExpression.body;
    final funcElement = FunctionElementImpl(
      name: node.name.lexeme,
      library: libraryElement,
      isExternal: node.externalKeyword != null,
      isOperator: false,
      isAsynchronous: body.isAsynchronous,
      isGenerator: body.isGenerator,
      isSynchronous: body.isSynchronous,
    );
    libraryElement.resolvedElements.add(funcElement);
    visitElementScoped(funcElement, () {
      node.functionExpression.typeParameters?.visitChildren(this);
      node.functionExpression.parameters?.visitChildren(this);
    });
    final returnType = _resolveType(node.returnType, funcElement, funcElement.typeParameters);
    funcElement.setReturnType(returnType);
    funcElement.type = FunctionTypeImpl(
      name: funcElement.name,
      returnType: returnType,
      typeParameters: funcElement.typeParameters,
      parameters: funcElement.parameters,
    );
  }

  @override
  void visitSimpleFormalParameter(SimpleFormalParameter node) {
    final executableElement = currentElementAs<ExecutableElementImpl>();
    final parameterType = _resolveType(node.type, executableElement, executableElement.typeParameters);

    final parameterElement = ParameterElementImpl(
      name: node.name?.lexeme ?? '',
      isConst: node.isConst,
      isFinal: node.isFinal,
      isLate: node.isOptional,
      type: parameterType,
      hasImplicitType: node.isExplicitlyTyped,
      enclosingElement: executableElement,
      isCovariant: node.covariantKeyword != null,
      isInitializingFormal: false,
      isNamed: node.isNamed,
      isOptional: node.isOptional,
      isPositional: node.isPositional,
      isRequired: node.isRequired,
      isRequiredNamed: node.isRequiredNamed,
      isRequiredPositional: node.isRequiredPositional,
      isOptionalNamed: node.isOptionalNamed,
      isOptionalPositional: node.isOptionalPositional,
      defaultValueCode: null,
      isSuperFormal: false,
    );
    executableElement.addParameter(parameterElement);
  }

  @override
  void visitTopLevelVariableDeclaration(TopLevelVariableDeclaration node) {
    for (final variable in node.variables.variables) {
      if (variable.initializer != null) {
        final constantEvaluator = ConstantEvaluator(_resolver, currentElementAs().library);
        final constValue = constantEvaluator.evaluate(variable.initializer!);
        print('${node.name} -> $constValue of type ${constValue.runtimeType}');
      }
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
    // pushElement(method);
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
