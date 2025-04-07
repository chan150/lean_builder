import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:code_genie/src/resolvers/const/const_evaluator.dart';
import 'package:code_genie/src/resolvers/const/constant.dart';
import 'package:code_genie/src/resolvers/element/element.dart';
import 'package:code_genie/src/resolvers/element_resolver.dart';
import 'package:code_genie/src/resolvers/type/type.dart';
import 'package:code_genie/src/resolvers/type/type_ref.dart';
import 'package:code_genie/src/resolvers/visitor/element_stack.dart';

class ElementResolverVisitor extends UnifyingAstVisitor<void> with ElementStack {
  final ElementResolver _resolver;

  ElementResolverVisitor(this._resolver, LibraryElement rootLibrary) {
    pushElement(rootLibrary);
  }

  @override
  void visitImportDirective(ImportDirective node) {
    final libraryElement = currentElementAs<LibraryElementImpl>();
    final combinators = <NamespaceCombinator>[];
    for (final combinator in node.combinators) {
      if (combinator is ShowCombinator) {
        final showNames = List<String>.unmodifiable(combinator.shownNames.map((e) => e.name));
        combinators.add(ShowElementCombinator(showNames));
      } else if (combinator is HideCombinator) {
        final hideNames = List<String>.unmodifiable(combinator.hiddenNames.map((e) => e.name));
        combinators.add(HideElementCombinator(hideNames));
      }
    }
    final importElement = ImportElementImpl(
      uri: Uri.parse(node.uri.stringValue ?? ''),
      library: libraryElement,
      combinators: combinators,
      isDeferred: node.deferredKeyword != null,
      prefix: node.prefix?.name,
    );
    libraryElement.addElement(importElement);
  }

  @override
  void visitExportDirective(ExportDirective node) {
    final libraryElement = currentElementAs<LibraryElementImpl>();
    final combinators = <NamespaceCombinator>[];
    for (final combinator in node.combinators) {
      if (combinator is ShowCombinator) {
        final showNames = List<String>.unmodifiable(combinator.shownNames.map((e) => e.name));
        combinators.add(ShowElementCombinator(showNames));
      } else if (combinator is HideCombinator) {
        final hideNames = List<String>.unmodifiable(combinator.hiddenNames.map((e) => e.name));
        combinators.add(HideElementCombinator(hideNames));
      }
    }
    final exportElement = ExportElementImpl(
      uri: Uri.parse(node.uri.stringValue ?? ''),
      library: libraryElement,
      combinators: combinators,
    );
    libraryElement.addElement(exportElement);
  }

  @override
  void visitPartDirective(PartDirective node) {
    final libraryElement = currentElementAs<LibraryElementImpl>();
    final partElement = PartElementImpl(uri: Uri.parse(node.uri.stringValue ?? ''), library: libraryElement);
    libraryElement.addElement(partElement);
  }

  @override
  void visitPartOfDirective(PartOfDirective node) {
    final libraryElement = currentElementAs<LibraryElementImpl>();
    final partOfElement = PartOfElementImpl(uri: Uri.parse(node.uri?.stringValue ?? ''), library: libraryElement);
    libraryElement.addElement(partOfElement);
  }

  @override
  void visitClassTypeAlias(ClassTypeAlias node) {
    final library = currentLibrary();
    if (library.getTypeAlias(node.name.lexeme) != null) {
      return;
    }
    final clazzElement = ClassElementImpl(name: node.name.lexeme, library: library);
    visitElementScoped(clazzElement, () => node.typeParameters?.visitChildren(this));
    _resolveSuperType(clazzElement, node.superclass);
    _resolveInterfaces(clazzElement, withClause: node.withClause, implementsClause: node.implementsClause);
    final aliasElement = TypeAliasElementImpl(name: node.name.lexeme, library: library);
    library.addElement(aliasElement);
    aliasElement.aliasedType = clazzElement.superType;
    aliasElement.typeParameters.addAll(clazzElement.typeParameters);
  }

  void _resolveSuperType(InterfaceElementImpl element, NamedType? type) {
    if (type == null) return;
    final resolvedSuperType = resolveType(NamedTypeRef.from(type), element);
    assert(resolvedSuperType is InterfaceType, 'Super type must be an interface type');
    element.superType = resolvedSuperType as InterfaceType;
  }

  void _resolveInterfaces(
    InterfaceElementImpl element, {
    WithClause? withClause,
    ImplementsClause? implementsClause,
    MixinOnClause? onClause,
  }) {
    if (withClause != null) {
      for (final mixin in withClause.mixinTypes) {
        final mixinType = resolveType(NamedTypeRef.from(mixin), element);
        assert(mixinType is InterfaceType, 'Mixin type must be an interface type');
        element.addMixin(mixinType as InterfaceType);
      }
    }
    if (implementsClause != null) {
      for (final interface in implementsClause.interfaces) {
        final interfaceType = resolveType(NamedTypeRef.from(interface), element);
        assert(interfaceType is InterfaceType, 'Interface type must be an interface type');
        element.addInterface(interfaceType as InterfaceType);
      }
    }

    if (onClause != null) {
      assert(element is MixinElementImpl);
      for (final interface in onClause.superclassConstraints) {
        final interfaceType = resolveType(NamedTypeRef.from(interface), element);
        assert(interfaceType is InterfaceType, 'Interface type must be an interface type');
        (element as MixinElementImpl).addSuperConstrain(interfaceType as InterfaceType);
      }
    }
  }

  @override
  void visitGenericTypeAlias(GenericTypeAlias node) {
    final library = currentLibrary();
    final typeAliasElm = TypeAliasElementImpl(name: node.name.lexeme, library: library);
    library.addElement(typeAliasElm);
    visitElementScoped(typeAliasElm, () {
      node.typeParameters?.visitChildren(this);
    });
    final targetType = node.functionType != null ? node.functionType! : node.type;
    final type = resolveType(TypeRef.from(targetType), typeAliasElm);
    typeAliasElm.aliasedType = type;
  }

  @override
  void visitFunctionTypeAlias(FunctionTypeAlias node) {
    final typeRef = FunctionTypeRef(
      node.name.lexeme,
      isNullable: false,
      parameters: node.parameters,
      typeParameters: node.typeParameters,
      returnType: TypeRef.from(node.returnType),
    );

    final library = currentLibrary();
    final typeAliasElm = TypeAliasElementImpl(name: node.name.lexeme, library: library);
    library.addElement(typeAliasElm);
    visitElementScoped(typeAliasElm, () {
      typeRef.typeParameters?.visitChildren(this);
    });
    final type = resolveType(typeRef, currentElementAs<ElementImpl>());
    typeAliasElm.aliasedType = type;
  }

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final libraryElement = currentLibrary();
    if (libraryElement.getClass(node.name.lexeme) != null) {
      return;
    }
    final classElement = ClassElementImpl(name: node.name.lexeme, library: libraryElement);
    libraryElement.resolvedElements.add(classElement);
    classElement.thisType = InterfaceTypeImpl(classElement, isNullable: false);

    visitElementScoped(classElement, () {
      node.typeParameters?.visitChildren(this);
      node.metadata.accept(this);
      for (final field in node.members.whereType<FieldDeclaration>()) {
        field.accept(this);
      }
      for (final method in node.members.whereType<MethodDeclaration>()) {
        method.accept(this);
      }
    });

    _resolveSuperType(classElement, node.extendsClause?.superclass);
    visitElementScoped(classElement, () {
      for (final constructor in node.members.whereType<ConstructorDeclaration>()) {
        constructor.accept(this);
      }
    });
    _resolveInterfaces(classElement, withClause: node.withClause, implementsClause: node.implementsClause);
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
    mixinElement.thisType = InterfaceTypeImpl(mixinElement, isNullable: false);

    visitElementScoped(mixinElement, () {
      node.typeParameters?.visitChildren(this);
    });

    _resolveInterfaces(mixinElement, implementsClause: node.implementsClause, onClause: node.onClause);
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
    enumElement.thisType = InterfaceTypeImpl(enumElement, isNullable: false);
    visitElementScoped(enumElement, () {
      for (final constant in node.constants) {
        final constantName = constant.name.lexeme;
        final fieldEle = FieldElementImpl(
          isStatic: true,
          name: constantName,
          isAbstract: false,
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
  void visitGenericFunctionType(GenericFunctionType node) {
    // final libraryElement = currentLibrary();
    // final funcEle = FunctionElementImpl(name: '', library: libraryElement);
    // resolveFunctionType(node, funcEle);
    // libraryElement.resolvedElements.add(funcEle);
  }

  @override
  void visitTypeParameter(TypeParameter node) {
    final element = currentElementAs<TypeParameterizedElementMixin>();
    final bound = node.bound;
    DartType boundType = DartType.dynamicType;
    if (bound != null) {
      boundType = resolveType(TypeRef.from(bound), element);
    }
    element.addTypeParameter(TypeParameterElementImpl(element, node.name.lexeme, boundType));
  }

  Element resolveTopLevelElement(IdentifierRef identifier, LibraryElement enclosingLibrary) {
    final (library, decNode) = _resolver.astNodeFor(identifier, enclosingLibrary);
    Element? decEle = library.getElement(identifier.name);
    if (decEle != null) {
      return decEle;
    }
    visitElementScoped(library, () => decNode.accept(this));
    decEle = library.getElement(identifier.name);
    assert(decEle != null, 'Element $identifier could not be resolved ${library.src.uri}');
    return decEle!;
  }

  DartType resolveType(TypeRef typeRef, Element enclosingEle) {
    if (!typeRef.isValid) {
      return DartType.neverType;
    }
    if (enclosingEle is TypeParameterizedElementMixin) {
      for (final typeParam in enclosingEle.allTypeParameters) {
        if (typeParam.name == typeRef.name) {
          return TypeParameterType(typeParam, bound: typeParam.bound, isNullable: typeRef.isNullable);
        }
      }
    }

    if (typeRef is NamedTypeRef) {
      return resolveNamedType(typeRef, enclosingEle);
    } else if (typeRef is FunctionTypeRef) {
      return resolveFunctionType(typeRef, FunctionElementImpl(name: typeRef.name, enclosingElement: enclosingEle));
    }
    return DartType.neverType;
  }

  FunctionType resolveFunctionType(FunctionTypeRef typeRef, FunctionElement funcElement) {
    visitElementScoped(funcElement, () {
      typeRef.typeParameters?.visitChildren(this);
      typeRef.parameters.visitChildren(this);
    });
    return FunctionTypeImpl(
      name: funcElement.name,
      returnType: resolveType(typeRef.returnType, funcElement),
      typeParameters: funcElement.typeParameters,
      parameters: funcElement.parameters,
      isNullable: typeRef.isNullable,
    );
  }

  DartType resolveNamedType(NamedTypeRef typeRef, Element enclosingEle) {
    final typename = typeRef.name;
    if (typename == DartType.voidType.name) {
      return DartType.voidType;
    }
    if (typename == DartType.dynamicType.name) {
      return DartType.dynamicType;
    }

    final typeArgs = <DartType>[];
    for (final typeArg in typeRef.typeArguments) {
      typeArgs.add(resolveType(typeArg, enclosingEle));
    }

    final element = resolveTopLevelElement(
      IdentifierRef(typename, importPrefix: typeRef.importPrefix),
      enclosingEle.library,
    );
    if (element is InterfaceElement) {
      return InterfaceTypeImpl(element, typeArguments: typeArgs, isNullable: typeRef.isNullable);
    } else if (element is TypeAliasElementImpl) {
      return element.instantiate(typeArguments: typeArgs, isNullable: typeRef.isNullable);
    }

    throw Exception('Unsupported type element: ${element.runtimeType}');
  }

  @override
  void visitFieldDeclaration(FieldDeclaration node) {
    final interfaceElement = currentElementAs<InterfaceElementImpl>();
    final fieldType = resolveType(TypeRef.from(node.fields.type), interfaceElement);
    final constEvaluator = ConstantEvaluator(_resolver, interfaceElement.library, this);
    // Process each variable in the field declaration
    for (final variable in node.fields.variables) {
      final fieldEle = FieldElementImpl(
        isStatic: node.isStatic,
        name: variable.name.lexeme,
        isAbstract: node.abstractKeyword != null,
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
      if (variable.initializer != null) {
        fieldEle.setConstantComputeValue(() {
          return constEvaluator.evaluate(variable.initializer!);
        });
      }
      interfaceElement.addField(fieldEle);
    }
  }

  @override
  void visitAnnotation(Annotation node) {
    return;
    final (lib, targetNode) = _resolver.astNodeFor(IdentifierRef.from(node.name), currentLibrary());
    pushElement(lib);
    // final constantEvaluator = ConstantEvaluator(_resolver, lib, this);
    // if (targetNode is ClassDeclaration) {
    //   visitClassDeclaration(targetNode);
    //   final clazz = lib.getClass(targetNode.name.lexeme);
    //   Map<String, Constant> argumentValues = {};
    //   if (node.arguments != null) {
    //     // Handle positional arguments
    //     for (var i = 0; i < node.arguments!.arguments.length; i++) {
    //       final arg = node.arguments!.arguments[i];
    //       if (arg is NamedExpression) {
    //         // Handle named arguments
    //         final name = arg.name.label.name;
    //         final value = constantEvaluator.evaluate(arg.expression);
    //         argumentValues[name] = value;
    //       } else {
    //         // Handle positional arguments - need to map to parameter names
    //         final value = constantEvaluator.evaluate(arg);
    //         // Use parameter index as temporary key for positional args
    //         argumentValues['$i'] = value;
    //       }
    //     }
    //   }
    //   // print(argumentValues);
    // }

    popElement();

    // final constValue = constVisitor.evaluate(node);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    final libraryElement = currentLibrary();
    if (libraryElement.getFunction(node.name.lexeme) != null) {
      return;
    }
    final body = node.functionExpression.body;
    final funcElement = FunctionElementImpl(
      name: node.name.lexeme,
      enclosingElement: libraryElement,
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
    final returnType = resolveType(TypeRef.from(node.returnType), funcElement);
    funcElement.returnType = returnType;
    funcElement.type = FunctionTypeImpl(
      name: funcElement.name,
      returnType: returnType,
      typeParameters: funcElement.typeParameters,
      parameters: funcElement.parameters,
      isNullable: false,
    );
  }

  @override
  void visitSimpleFormalParameter(SimpleFormalParameter node) {
    final name = node.name?.lexeme ?? '';
    final executableElement = currentElementAs<ExecutableElementImpl>();
    if (executableElement.getParameter(name) != null) {
      return;
    }
    final parameterElement = _buildParameter(node, executableElement);
    executableElement.addParameter(parameterElement);
  }

  @override
  void visitDefaultFormalParameter(DefaultFormalParameter node) {
    node.parameter.accept(this);
    final executableElement = currentElementAs<ExecutableElementImpl>();
    final param = executableElement.getParameter(node.name?.lexeme ?? '') as ParameterElementImpl?;
    if (param != null && node.defaultValue != null) {
      param.setConstantComputeValue(() {
        final constEvaluator = ConstantEvaluator(_resolver, executableElement.library, this);
        return constEvaluator.evaluate(node.defaultValue!);
      });
    }
  }

  // field formal parameter
  @override
  void visitFieldFormalParameter(FieldFormalParameter node) {
    final name = node.name.lexeme;
    final constructorEle = currentElementAs<ConstructorElementImpl>();
    if (constructorEle.getParameter(name) != null) {
      return;
    }
    final clazzElem = constructorEle.enclosingElement as ClassElementImpl;
    final fields = clazzElem.fields;
    final thisType =
        fields.firstWhere((e) => e.name == name, orElse: () => throw Exception('Could not link this type')).type;
    final parameterElement = _buildParameter(node, constructorEle, type: thisType);
    constructorEle.addParameter(parameterElement);
  }

  @override
  void visitSuperFormalParameter(SuperFormalParameter node) {
    final name = node.name.lexeme;
    final constructorEle = currentElementAs<ConstructorElementImpl>();
    if (constructorEle.getParameter(name) != null) {
      return;
    }

    final superParams = [...?constructorEle.superConstructor?.parameters];
    ParameterElementImpl? superParam;
    int paramIndex = -1;
    final paramsList = node.thisOrAncestorOfType<FormalParameterList>();
    if (paramsList != null) {
      paramIndex = paramsList.parameters.indexOf(node);
    }
    for (var index = 0; index < superParams.length; index++) {
      if (node.isPositional && superParams[index].isPositional && index == paramIndex) {
        superParam = superParams[index] as ParameterElementImpl;
        break;
      } else if (node.isNamed && superParams[index].isNamed && superParams[index].name == name) {
        superParam = superParams[index] as ParameterElementImpl;
        break;
      }
    }
    if (superParam == null) {
      throw Exception('Could not find super parameter for ${node.name}');
    }
    final parameterElement = _buildParameter(node, constructorEle, isSuperFormal: true, type: superParam.type);
    parameterElement.setConstantComputeValue(superParam.computeConstantValue);
    constructorEle.addParameter(parameterElement);
  }

  ParameterElementImpl _buildParameter(
    FormalParameter node,
    ExecutableElementImpl executableElement, {
    bool isSuperFormal = false,
    DartType? type,
  }) {
    final name = node.name?.lexeme ?? '';

    if (type == null && node is SimpleFormalParameter) {
      type = resolveType(TypeRef.from(node.type), executableElement);
    }

    final parameterElement = ParameterElementImpl(
      name: name,
      isConst: node.isConst,
      isFinal: node.isFinal,
      isLate: node.isOptional,
      hasImplicitType: node.isExplicitlyTyped,
      enclosingElement: executableElement,
      isCovariant: node.covariantKeyword != null,
      isInitializingFormal: node is FieldFormalParameter,
      isNamed: node.isNamed,
      isOptional: node.isOptional,
      isPositional: node.isPositional,
      isRequired: node.isRequired,
      isRequiredNamed: node.isRequiredNamed,
      isRequiredPositional: node.isRequiredPositional,
      isOptionalNamed: node.isOptionalNamed,
      isOptionalPositional: node.isOptionalPositional,
      isSuperFormal: isSuperFormal,
    );
    parameterElement.type = type ?? NeverType();
    return parameterElement;
  }

  @override
  void visitTopLevelVariableDeclaration(TopLevelVariableDeclaration node) {
    final library = currentLibrary();
    final constantEvaluator = ConstantEvaluator(_resolver, library, this);
    for (final variable in node.variables.variables) {
      final topLevelVar = TopLevelVariableElementImpl(
        name: variable.name.lexeme,
        isConst: node.variables.isConst,
        isFinal: node.variables.isFinal,
        isLate: node.variables.isLate,
        isExternal: node.externalKeyword != null,
        hasImplicitType: node.variables.type == null,
        enclosingElement: library,
      );
      topLevelVar.type = resolveType(TypeRef.from(node.variables.type), library);
      if (variable.initializer != null) {
        topLevelVar.setConstantComputeValue(() {
          return constantEvaluator.evaluate(variable.initializer!);
        });
      }
      library.addElement(topLevelVar);
    }
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    final interfaceElement = currentElementAs<InterfaceElementImpl>();
    if (interfaceElement.getMethod(node.name.lexeme) != null) {
      return;
    }
    final methodElement = MethodElementImpl(
      isStatic: node.isStatic,
      name: node.name.lexeme,
      enclosingElement: interfaceElement,
      isAbstract: node.isAbstract,
      isAsynchronous: node.body.isAsynchronous,
      isExternal: node.externalKeyword != null,
      isGenerator: node.body.isGenerator,
      isOperator: node.isOperator,
      isSynchronous: node.body.isSynchronous,
    );
    interfaceElement.addMethod(methodElement);

    visitElementScoped(methodElement, () {
      node.typeParameters?.visitChildren(this);
      node.parameters?.visitChildren(this);
    });
    final returnType = resolveType(TypeRef.from(node.returnType), methodElement);
    methodElement.returnType = returnType;
    methodElement.type = FunctionTypeImpl(
      name: methodElement.name,
      returnType: returnType,
      typeParameters: methodElement.typeParameters,
      parameters: methodElement.parameters,
      isNullable: false,
    );
  }

  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) {
    final clazzElement = currentElementAs<ClassElementImpl>();
    final name = node.name?.lexeme ?? '';
    if (clazzElement.getConstructor(name) != null) {
      return;
    }

    final initializers = node.initializers;
    ConstructorElement? superConstructor;
    if (clazzElement.superType != null) {
      final superConstName =
          initializers.whereType<SuperConstructorInvocation>().map((e) => e.constructorName?.name).firstOrNull;
      final superClazz = clazzElement.superType!.element as ClassElementImpl;
      superConstructor = superClazz.getConstructor(superConstName ?? '');
    }

    final constructorElement = ConstructorElementImpl(
      name: name,
      enclosingElement: clazzElement,
      isConst: node.constKeyword != null,
      isFactory: node.factoryKeyword != null,
      isDefaultConstructor: false,
      isGenerative: node.body.isGenerator,
      superConstructor: superConstructor,
    );
    clazzElement.addConstructor(constructorElement);

    constructorElement.returnType = clazzElement.thisType;

    visitElementScoped(constructorElement, () {
      node.parameters.visitChildren(this);
    });

    for (final initializer in initializers) {
      if (initializer is ConstructorFieldInitializer) {
        final field = clazzElement.getField(initializer.fieldName.name) as FieldElementImpl?;
        if (field != null) {
          field.setConstantComputeValue(() {
            return _evaluateConstant(initializer.expression, clazzElement.library);
          });
        }
      }
    }

    final redirectType = node.redirectedConstructor?.type;
    if (redirectType != null) {
      // String? nameOverride;
      // if (redirectType.importPrefix != null) {
      //   final imports = node.root.childEntities.whereType<ImportDirective>();
      //   final importPrefix = redirectType.importPrefix!.name.lexeme;
      //
      //   /// if it's not an actual import prefix, it's a redirect to a class's constructor
      //   if (imports.every((i) => i.prefix?.name != importPrefix) || true) {
      //     nameOverride = importPrefix;
      //   }
      // }
      // final type = resolveType(TypeRef(redirectType, nameOverride), clazzElement) as InterfaceType;
      // constructorElement.returnType = type;
      // final redirectClass = type.element as ClassElementImpl;
      // final redirectConstructor = redirectClass.getConstructor(nameOverride == null ? '' : redirectType.name2.lexeme);
      // constructorElement.redirectedConstructor = redirectConstructor;
    }
  }

  Constant? _evaluateConstant(Expression expression, LibraryElement library) {
    final constEvaluator = ConstantEvaluator(_resolver, library, this);
    return constEvaluator.evaluate(expression);
  }
}
