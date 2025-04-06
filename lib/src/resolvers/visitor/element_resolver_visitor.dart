import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:code_genie/src/resolvers/const/const_evaluator.dart';
import 'package:code_genie/src/resolvers/const/constant.dart';
import 'package:code_genie/src/resolvers/element/element.dart';
import 'package:code_genie/src/resolvers/element_resolver.dart';
import 'package:code_genie/src/resolvers/type/type.dart';
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
        combinators.add(ShowElementCombinator(List.unmodifiable(combinator.shownNames.map((e) => e.name))));
      } else if (combinator is HideCombinator) {
        combinators.add(HideElementCombinator(List.unmodifiable(combinator.hiddenNames.map((e) => e.name))));
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
        combinators.add(ShowElementCombinator(List.unmodifiable(combinator.shownNames.map((e) => e.name))));
      } else if (combinator is HideCombinator) {
        combinators.add(HideElementCombinator(List.unmodifiable(combinator.hiddenNames.map((e) => e.name))));
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
    print('Visiting class type alias ${node}');
  }

  @override
  void visitGenericTypeAlias(GenericTypeAlias node) {
    print('Visiting generic type alias ${node}');
  }

  @override
  void visitFunctionTypeAlias(TypeAlias node) {
    print('Visiting type alias ${node}');
  }

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    print('Visiting class ${node.name.lexeme}');
    final libraryElement = currentLibrary();
    if (libraryElement.getClass(node.name.lexeme) != null) {
      return;
    }
    final classElement = ClassElementImpl(name: node.name.lexeme, library: libraryElement);
    libraryElement.resolvedElements.add(classElement);
    classElement.thisType = InterfaceTypeImpl(classElement);

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

    final superType = node.extendsClause?.superclass;
    if (superType != null) {
      final resolvedSuperType = resolveType(TypeRef(superType), classElement);
      assert(resolvedSuperType is InterfaceType, 'Super type must be an interface type');
      classElement.superType = resolvedSuperType as InterfaceType;
    }

    visitElementScoped(classElement, () {
      for (final constructor in node.members.whereType<ConstructorDeclaration>()) {
        constructor.accept(this);
      }
    });

    for (final mixin in [...?node.withClause?.mixinTypes]) {
      final mixinType = resolveType(TypeRef(mixin), classElement);
      assert(mixinType is InterfaceType, 'Mixin type must be an interface type');
      classElement.addMixin(mixinType as InterfaceType);
    }

    for (final interface in [...?node.implementsClause?.interfaces]) {
      final interfaceType = resolveType(TypeRef(interface), classElement);
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
      final interfaceType = resolveType(TypeRef(interface), mixinElement);
      assert(interfaceType is InterfaceType, 'Interface type must be an interface type');
      mixinElement.addInterface(interfaceType as InterfaceType);
    }

    for (final on in [...?node.onClause?.superclassConstraints]) {
      final onType = resolveType(TypeRef(on), mixinElement);
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
    InterfaceType? boundType;
    if (bound != null) {
      boundType = resolveType(TypeRef(bound), element) as InterfaceType;
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
    if (decEle == null) {
      // print(StackTrace.current);
    }
    decEle = library.getElement(identifier.name);
    assert(decEle != null, 'Element $identifier could not be resolved ${library.src.uri}');
    return decEle!;
  }

  DartType resolveType(TypeRef typeRef, Element enclosingEle) {
    if (typeRef.annotation == null) {
      return NeverType();
    }

    final typeAnno = typeRef.annotation;
    if (enclosingEle is TypeParameterizedElementMixin) {
      for (final typeParam in enclosingEle.allTypeParameters) {
        if (typeParam.name == typeRef.name) {
          return TypeParameterType(typeParam, typeParam.bound ?? DynamicType());
        }
      }
    }

    if (typeAnno is NamedType) {
      return _resolveNamedType(TypeRef(typeAnno, typeRef.nameOverride), enclosingEle);
    } else if (typeAnno is GenericFunctionType) {
      return resolveFunctionType(typeAnno, FunctionElementImpl(name: '', library: enclosingEle.library));
    }
    return NeverType();
  }

  FunctionType resolveFunctionType(GenericFunctionType typeAnno, FunctionElement funcElement) {
    visitElementScoped(funcElement, () {
      typeAnno.typeParameters?.visitChildren(this);
      typeAnno.parameters.visitChildren(this);
    });
    final returnType = resolveType(TypeRef(typeAnno.returnType), funcElement);
    return FunctionTypeImpl(
      name: funcElement.name,
      returnType: returnType,
      typeParameters: funcElement.typeParameters,
      parameters: funcElement.parameters,
    );
  }

  DartType _resolveNamedType(TypeRef<NamedType> typeRef, Element enclosingEle) {
    final typename = typeRef.name;
    if (typename == DartType.voidType.name) {
      return DartType.voidType;
    }
    if (typename == DartType.dynamicType.name) {
      return DartType.dynamicType;
    }

    final element = resolveTopLevelElement(IdentifierRef(typename), enclosingEle.library) as InterfaceElement;
    final typeArgs = <DartType>[];
    for (final typeArg in [...?typeRef.annotation?.typeArguments?.arguments]) {
      typeArgs.add(resolveType(TypeRef(typeArg), enclosingEle));
    }

    return InterfaceTypeImpl(element, typeArgs);
  }

  @override
  void visitFieldDeclaration(FieldDeclaration node) {
    final interfaceElement = currentElementAs<InterfaceElementImpl>();
    final fieldType = resolveType(TypeRef(node.fields.type), interfaceElement);
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
    final returnType = resolveType(TypeRef(node.returnType), funcElement);
    funcElement.returnType = returnType;
    funcElement.type = FunctionTypeImpl(
      name: funcElement.name,
      returnType: returnType,
      typeParameters: funcElement.typeParameters,
      parameters: funcElement.parameters,
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
      type = resolveType(TypeRef(node.type), executableElement);
    }

    final parameterElement = ParameterElementImpl(
      name: name,
      isConst: node.isConst,
      isFinal: node.isFinal,
      isLate: node.isOptional,
      type: type ?? NeverType(),
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

    return parameterElement;
  }

  @override
  void visitTopLevelVariableDeclaration(TopLevelVariableDeclaration node) {
    final library = currentLibrary();
    final constantEvaluator = ConstantEvaluator(_resolver, library, this);
    final type = resolveType(TypeRef(node.variables.type), library);
    for (final variable in node.variables.variables) {
      final topLevelVar = TopLevelVariableElementImpl(
        name: variable.name.lexeme,
        isConst: node.variables.isConst,
        isFinal: node.variables.isFinal,
        isLate: node.variables.isLate,
        isExternal: node.externalKeyword != null,
        type: type,
        hasImplicitType: node.variables.type == null,
        enclosingElement: library,
      );
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
    print('Visiting method ${node.name.lexeme}');

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
    final returnType = resolveType(TypeRef(node.returnType), methodElement);
    methodElement.returnType = returnType;
    methodElement.type = FunctionTypeImpl(
      name: methodElement.name,
      returnType: returnType,
      typeParameters: methodElement.typeParameters,
      parameters: methodElement.parameters,
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
