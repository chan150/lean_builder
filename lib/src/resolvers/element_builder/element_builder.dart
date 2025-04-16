import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:lean_builder/src/resolvers/const/const_evaluator.dart';
import 'package:lean_builder/src/resolvers/const/constant.dart';
import 'package:lean_builder/src/resolvers/element/element.dart';
import 'package:lean_builder/src/resolvers/element_resolver.dart';
import 'package:lean_builder/src/resolvers/type/type_ref.dart';
import 'package:lean_builder/src/resolvers/element_builder/element_stack.dart';
import 'package:lean_builder/src/scanner/scan_results.dart';

class ElementBuilder extends UnifyingAstVisitor<void> with ElementStack {
  final ElementResolver _resolver;

  ElementBuilder(this._resolver, LibraryElement rootLibrary) {
    pushElement(rootLibrary);
  }

  @override
  void visitExtensionTypeDeclaration(ExtensionTypeDeclaration node) {
    final library = currentLibrary();
    if (library.hasElement(node.name.lexeme)) return;
    final clazzElement = InterfaceElementImpl(name: node.name.lexeme, library: library);
    library.addElement(clazzElement);
    visitElementScoped(clazzElement, () {
      node.typeParameters?.visitChildren(this);
      node.metadata.accept(this);

      for (final field in node.members.whereType<FieldDeclaration>()) {
        field.accept(this);
      }
      for (final method in node.members.whereType<MethodDeclaration>()) {
        method.accept(this);
      }
    });

    _resolveInterfaceTypeRefs(clazzElement, implementsClause: node.implementsClause);

    clazzElement.thisType = NamedTypeRefImpl(
      clazzElement.name,
      library.buildLocation(clazzElement.name, TopLevelIdentifierType.$class),
    );
    visitElementScoped(clazzElement, () {
      for (final constructor in node.members.whereType<ConstructorDeclaration>()) {
        constructor.accept(this);
      }
    });
  }

  @override
  void visitClassTypeAlias(ClassTypeAlias node) {
    final library = currentLibrary();
    if (library.hasElement(node.name.lexeme)) return;
    final clazzElement = ClassElementImpl(
      library: library,
      name: node.name.lexeme,
      isAbstract: node.abstractKeyword != null || node.sealedKeyword != null,
      isSealed: node.sealedKeyword != null,
      isBase: node.baseKeyword != null,
      isInterface: node.interfaceKeyword != null,
      isMixinClass: node.mixinKeyword != null,
      isFinal: node.finalKeyword != null,
      isMixinApplication: true,
    );
    visitElementScoped(clazzElement, () => node.typeParameters?.visitChildren(this));
    _resolveSuperTypeRef(clazzElement, node.superclass);
    _resolveInterfaceTypeRefs(clazzElement, withClause: node.withClause, implementsClause: node.implementsClause);
    library.addElement(clazzElement);
  }

  void _resolveSuperTypeRef(InterfaceElementImpl element, NamedType? type) {
    if (type == null) return;
    final resolvedSuperType = resolveTypeRef(type, element);
    assert(resolvedSuperType is NamedTypeRef, 'Super type must be an interface type ${resolvedSuperType.runtimeType}');
    element.superType = resolvedSuperType as NamedTypeRef;
  }

  void _resolveInterfaceTypeRefs(
    InterfaceElementImpl element, {
    WithClause? withClause,
    ImplementsClause? implementsClause,
    MixinOnClause? onClause,
  }) {
    if (withClause != null) {
      for (final mixin in withClause.mixinTypes) {
        final mixinType = resolveTypeRef((mixin), element);
        assert(mixinType is NamedTypeRef, 'Mixin type must be an interface type');
        element.addMixin(mixinType as NamedTypeRef);
      }
    }
    if (implementsClause != null) {
      for (final interface in implementsClause.interfaces) {
        final interfaceType = resolveTypeRef((interface), element);
        assert(interfaceType is NamedTypeRef, 'Interface type must be an interface type');
        element.addInterface(interfaceType as NamedTypeRef);
      }
    }

    if (onClause != null) {
      assert(element is MixinElementImpl);
      for (final interface in onClause.superclassConstraints) {
        final interfaceType = resolveTypeRef((interface), element);
        assert(interfaceType is NamedTypeRef, 'Interface type must be an interface type');
        (element as MixinElementImpl).addSuperConstrain(interfaceType as NamedTypeRef);
      }
    }
  }

  @override
  void visitGenericTypeAlias(GenericTypeAlias node) {
    final library = currentLibrary();
    if (library.hasElement(node.name.lexeme)) return;
    final typeAliasElm = TypeAliasElementImpl(name: node.name.lexeme, library: library);
    library.addElement(typeAliasElm);
    visitElementScoped(typeAliasElm, () {
      node.typeParameters?.visitChildren(this);
    });
    final targetType = node.functionType != null ? node.functionType! : node.type;
    final type = resolveTypeRef((targetType), typeAliasElm);
    typeAliasElm.aliasedType = type;
  }

  @override
  void visitFunctionTypeAlias(FunctionTypeAlias node) {
    final library = currentLibrary();
    if (library.hasElement(node.name.lexeme)) return;
    final funcElement = FunctionElementImpl(name: node.name.lexeme, enclosingElement: library);
    visitElementScoped(funcElement, () {
      node.typeParameters?.visitChildren(this);
      node.parameters.visitChildren(this);
    });
    final typeAliasElm = TypeAliasElementImpl(name: node.name.lexeme, library: library);
    library.addElement(typeAliasElm);
    typeAliasElm.aliasedType = FunctionTypeRef(
      isNullable: false,
      parameters: funcElement.parameters,
      typeParameters: funcElement.typeParameters,
      returnType: resolveTypeRef(node.returnType, funcElement),
    );
  }

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final library = currentLibrary();
    if (library.hasElement(node.name.lexeme)) return;
    final isSealed = node.sealedKeyword != null;
    final classElement = ClassElementImpl(
      name: node.name.lexeme,
      library: library,
      isAbstract: node.abstractKeyword != null || node.sealedKeyword != null,
      isSealed: isSealed,
      isBase: node.baseKeyword != null,
      isFinal: node.finalKeyword != null,
      isInterface: node.interfaceKeyword != null,
      isMixinClass: node.mixinKeyword != null,
      isMixinApplication: false,
    );
    library.addElement(classElement);

    visitElementScoped(classElement, () {
      node.typeParameters?.visitChildren(this);
      node.metadata.accept(this);
      for (final field in node.members.whereType<FieldDeclaration>()) {
        field.accept(this);
      }
    });

    classElement.thisType = NamedTypeRefImpl(
      classElement.name,
      library.buildLocation(classElement.name, TopLevelIdentifierType.$class),
      typeArguments: classElement.typeParameters,
    );
    _resolveSuperTypeRef(classElement, node.extendsClause?.superclass);
    visitElementScoped(classElement, () {
      for (final constructor in node.members.whereType<ConstructorDeclaration>()) {
        constructor.accept(this);
      }
    });
    _resolveInterfaceTypeRefs(classElement, withClause: node.withClause, implementsClause: node.implementsClause);
  }

  @override
  void visitMixinDeclaration(MixinDeclaration node) {
    final libraryElement = currentLibrary();
    if (libraryElement.hasElement(node.name.lexeme)) return;

    final mixinElement = MixinElementImpl(
      name: node.name.lexeme,
      library: libraryElement,
      isBase: node.baseKeyword != null,
    );
    libraryElement.addElement(mixinElement);

    visitElementScoped(mixinElement, () {
      node.typeParameters?.visitChildren(this);
    });
    mixinElement.thisType = NamedTypeRefImpl(
      mixinElement.name,
      libraryElement.buildLocation(mixinElement.name, TopLevelIdentifierType.$mixin),
      typeArguments: mixinElement.typeParameters,
    );
    _resolveInterfaceTypeRefs(mixinElement, implementsClause: node.implementsClause, onClause: node.onClause);
  }

  @override
  void visitEnumDeclaration(EnumDeclaration node) {
    final library = currentLibrary();
    if (library.hasElement(node.name.lexeme)) return;

    final enumElement = EnumElementImpl(name: node.name.lexeme, library: library);
    library.addElement(enumElement);

    enumElement.thisType = NamedTypeRefImpl(
      enumElement.name,
      library.buildLocation(enumElement.name, TopLevelIdentifierType.$enum),
    );

    visitElementScoped(enumElement, () {
      node.typeParameters?.visitChildren(this);
      node.metadata.accept(this);
    });
    _resolveInterfaceTypeRefs(enumElement);
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
  }

  @override
  void visitTypeParameter(TypeParameter node) {
    final element = currentElementAs<TypeParameterizedElementMixin>();
    final bound = node.bound;
    TypeRef boundType = TypeRef.dynamicType;
    if (bound != null) {
      boundType = resolveTypeRef(bound, element);
    }
    element.addTypeParameter(TypeParameterTypeRef(node.name.lexeme, bound: boundType));
  }

  TypeRef resolveTypeRef(TypeAnnotation? typeAnno, Element enclosingEle) {
    if (typeAnno == null) {
      return TypeRef.invalidType;
    }
    if (typeAnno is NamedType) {
      if (enclosingEle is TypeParameterizedElementMixin) {
        for (final typeParam in enclosingEle.allTypeParameters) {
          if (typeParam.name == typeAnno.name2.lexeme) {
            return typeParam.withNullability(typeAnno.question != null);
          }
        }
      }
      return resolveNamedTypeRef(typeAnno, enclosingEle);
    } else if (typeAnno is GenericFunctionType) {
      return resolveFunctionTypeRef(typeAnno, FunctionElementImpl(name: 'Function', enclosingElement: enclosingEle));
    } else if (typeAnno is RecordTypeAnnotation) {
      return resolveRecordTypeRef(typeAnno, enclosingEle);
    }
    return TypeRef.invalidType;
  }

  FunctionTypeRef resolveFunctionTypeRef(GenericFunctionType typeAnnotation, FunctionElement funcElement) {
    visitElementScoped(funcElement, () {
      typeAnnotation.typeParameters?.visitChildren(this);
      typeAnnotation.parameters.visitChildren(this);
    });
    return FunctionTypeRef(
      returnType: resolveTypeRef(typeAnnotation.returnType, funcElement),
      typeParameters: funcElement.typeParameters,
      parameters: funcElement.parameters,
      isNullable: typeAnnotation.question != null,
    );
  }

  RecordTypeRef resolveRecordTypeRef(RecordTypeAnnotation typeAnnotation, Element enclosingEle) {
    final positionalTypes = <RecordTypePositionalField>[];
    for (final field in typeAnnotation.positionalFields) {
      positionalTypes.add(RecordTypePositionalField(resolveTypeRef(field.type, enclosingEle)));
    }
    final namedTypes = <RecordTypeNamedField>[];
    for (final field in [...?typeAnnotation.namedFields?.fields]) {
      namedTypes.add(RecordTypeNamedField(field.name.lexeme, resolveTypeRef(field.type, enclosingEle)));
    }
    return RecordTypeRef(
      positionalFields: positionalTypes,
      namedFields: namedTypes,
      isNullable: typeAnnotation.question != null,
    );
  }

  TypeRef resolveNamedTypeRef(NamedType annotation, Element enclosingEle) {
    final typename = annotation.name2.lexeme;

    if (typename == TypeRef.voidType.name) return TypeRef.voidType;
    if (typename == TypeRef.dynamicType.name) return TypeRef.dynamicType;
    if (typename == TypeRef.invalidType.name) return TypeRef.neverType;

    final typeArgs = <TypeRef>[];
    for (final typeArg in [...?annotation.typeArguments?.arguments]) {
      typeArgs.add(resolveTypeRef(typeArg, enclosingEle));
    }

    final importPrefix = annotation.importPrefix;
    final identifierLocation = _resolver.getDeclarationRef(
      typename,
      enclosingEle.library.src,
      importPrefix: importPrefix?.name.lexeme,
    );
    if (identifierLocation == null) {
      throw Exception('Could not find identifier $typename in ${enclosingEle.library.src.shortPath}');
    }
    return NamedTypeRefImpl(
      typename,
      identifierLocation,
      isNullable: annotation.question != null,
      typeArguments: typeArgs,
    );
  }

  @override
  void visitFieldDeclaration(FieldDeclaration node) {
    final interfaceElement = currentElementAs<InterfaceElementImpl>();
    final fieldType = resolveTypeRef(node.fields.type, interfaceElement);
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
        fieldEle.initializer = variable.initializer;
        fieldEle.setConstantComputeValue(() {
          return constEvaluator.evaluate(variable.initializer!);
        });
      }
      interfaceElement.addField(fieldEle);
    }
  }

  @override
  void visitAnnotation(Annotation node) {
    final currentElement = currentElementAs<ElementImpl>();
    final name = node.name;
    final identifier = _resolver.resolveIdentifier(currentElement.library, [
      if (name is SimpleIdentifier) name.name,
      if (name is PrefixedIdentifier) ...[name.prefix.name, name.identifier.name],
    ]);
    final (lib, targetNode, loc) = _resolver.astNodeFor(identifier, currentElement.library);
    final constantEvaluator = ConstantEvaluator(_resolver, lib, this);
    if (targetNode is ClassDeclaration || targetNode is ConstructorDeclaration) {
      final classDeclaration = targetNode.thisOrAncestorOfType<ClassDeclaration>()!;
      final className = classDeclaration.name.lexeme;
      final elem = ElementAnnotationImpl(
        name: name.name,
        type: NamedTypeRefImpl(className, loc),
        constantValueCompute: () {
          final ConstructorDeclaration constructor;
          if (targetNode is ConstructorDeclaration) {
            constructor = targetNode;
          } else {
            constructor = classDeclaration.members.whereType<ConstructorDeclaration>().firstWhere(
              (e) => e.name?.lexeme == node.constructorName?.name,
              orElse: () => throw Exception('Could not find constructor'),
            );
          }
          final obj = constantEvaluator.evaluate(constructor) as ConstObjectImpl?;
          if (node.arguments != null) {
            return obj?.mergeArgs(node.arguments!, constantEvaluator);
          }
          return obj;
        },
      );
      currentElement.addMetadata(elem);
    } else if (targetNode is TopLevelVariableDeclaration || targetNode is FieldDeclaration) {
      final VariableDeclarationList varList;
      if (targetNode is TopLevelVariableDeclaration) {
        varList = targetNode.variables;
      } else {
        varList = (targetNode as FieldDeclaration).fields;
      }

      final variable = varList.variables.firstWhere((e) => e.name.lexeme == identifier.name);
      TypeRef typeRef = TypeRef.invalidType;
      final initializer = variable.initializer;
      if (varList.type != null) {
        typeRef = resolveTypeRef(varList.type!, currentElement);
      } else if (initializer is MethodInvocation) {
        final target = initializer.target;
        final parts = [
          if (target is SimpleIdentifier) ...[
            target.name,
            initializer.methodName.name,
          ] else if (target is PrefixedIdentifier) ...[
            target.prefix.name,
            target.identifier.name,
          ] else if (target == null)
            initializer.methodName.name,
        ];
        final identifier = _resolver.resolveIdentifier(lib, parts);
        final (_, _, loc) = _resolver.astNodeFor(identifier, lib);
        typeRef = NamedTypeRefImpl(identifier.topLevelTarget, loc);
      }
      final elem = ElementAnnotationImpl(
        name: identifier.name,
        type: typeRef,
        constantValueCompute: () {
          return constantEvaluator.evaluate(variable.initializer!);
        },
      );
      currentElement.addMetadata(elem);
    }
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    final libraryElement = currentLibrary();
    if (libraryElement.hasElement(node.name.lexeme)) return;
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
    libraryElement.addElement(funcElement);
    visitElementScoped(funcElement, () {
      node.functionExpression.typeParameters?.visitChildren(this);
      node.functionExpression.parameters?.visitChildren(this);
    });
    final returnType = resolveTypeRef((node.returnType), funcElement);
    funcElement.returnType = returnType;
    funcElement.type = FunctionTypeRef(
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
      param.initializer = node.defaultValue;
      param.setConstantComputeValue(() {
        final constEvaluator = ConstantEvaluator(_resolver, executableElement.library, this);
        return constEvaluator.evaluate(node.defaultValue!);
      });
    }
  }

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

  (TypeRef, Expression?) _resolveSuperParam({
    required IdentifierRef ref,
    required LibraryElementImpl library,
    required String constructorName,
    required SuperFormalParameter superParam,
  }) {
    final (lib, clazzNode as ClassDeclaration, _) = _resolver.astNodeFor(ref, library);

    final constructorNode = clazzNode.members.whereType<ConstructorDeclaration>().firstWhere(
      (e) => (e.name?.lexeme ?? '') == constructorName,
    );

    final FormalParameter targetParam;
    final ancestorParams = constructorNode.parameters.parameters;
    if (superParam.isNamed) {
      targetParam = ancestorParams.firstWhere(
        (e) => e.name?.lexeme == superParam.name.lexeme,
        orElse: () => throw Exception('Could not find super param'),
      );
    } else {
      final thisParams = [...?superParam.thisOrAncestorOfType<ConstructorDeclaration>()?.parameters.parameters];
      final superParamIndex = thisParams.indexWhere((p) => p.name?.lexeme == superParam.name.lexeme);
      if (superParamIndex != -1) {
        targetParam = ancestorParams[superParamIndex];
      } else {
        throw Exception('Could not find super param');
      }
    }

    InterfaceElement getTypeParamsCollector() {
      final typeParamsCollector = InterfaceElementImpl(name: '', library: lib);
      visitElementScoped(typeParamsCollector, () {
        clazzNode.typeParameters?.visitChildren(this);
      });
      return typeParamsCollector;
    }

    (TypeRef, Expression?) buildParam(FormalParameter param, LibraryElementImpl lib) {
      if (param is FieldFormalParameter) {
        final field = clazzNode.members.whereType<FieldDeclaration>().firstWhere(
          (e) => e.fields.variables.any((v) => v.name.lexeme == param.name.lexeme),
          orElse: () => throw Exception('Could not find field formal parameter'),
        );
        return (resolveTypeRef(field.fields.type, getTypeParamsCollector()), null);
      } else if (param is SimpleFormalParameter) {
        return (resolveTypeRef(param.type, getTypeParamsCollector()), null);
      } else if (param is DefaultFormalParameter) {
        return (buildParam(param.parameter, lib).$1, param.defaultValue);
      } else if (param is SuperFormalParameter) {
        final superInvocation = constructorNode.initializers.whereType<SuperConstructorInvocation>().singleOrNull;
        final superType = clazzNode.extendsClause!.superclass;
        return _resolveSuperParam(
          ref: IdentifierRef(superType.name2.lexeme, importPrefix: superType.importPrefix?.name.lexeme),
          library: lib,
          constructorName: superInvocation?.constructorName?.name ?? '',
          superParam: param,
        );
      } else {
        throw Exception('Unknown parameter type: ${param.runtimeType}');
      }
    }

    return buildParam(targetParam, lib);
  }

  @override
  void visitSuperFormalParameter(SuperFormalParameter node) {
    final name = node.name.lexeme;
    final constructorEle = currentElementAs<ConstructorElementImpl>();
    if (constructorEle.getParameter(name) != null) {
      return;
    }
    final library = currentLibrary();
    final superConstRef = constructorEle.superConstructor!;

    final (superType, initializer) = _resolveSuperParam(
      ref: IdentifierRef(superConstRef.classType.name, location: superConstRef.classType.src),
      library: library,
      constructorName: superConstRef.name,
      superParam: node,
    );
    final parameterElement = _buildParameter(node, constructorEle, isSuperFormal: true, type: superType);

    if (initializer != null) {
      parameterElement.setConstantComputeValue(() {
        final constEvaluator = ConstantEvaluator(_resolver, library, this);
        return constEvaluator.evaluate(initializer);
      });
    }
    constructorEle.addParameter(parameterElement);
  }

  ParameterElementImpl _buildParameter(
    FormalParameter node,
    ExecutableElementImpl executableElement, {
    bool isSuperFormal = false,
    TypeRef? type,
  }) {
    final name = node.name?.lexeme ?? '';

    if (type == null && node is SimpleFormalParameter) {
      type = resolveTypeRef((node.type), executableElement);
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
    parameterElement.type = type ?? TypeRef.neverType;
    return parameterElement;
  }

  @override
  void visitTopLevelVariableDeclaration(TopLevelVariableDeclaration node) {
    final library = currentLibrary();
    final constantEvaluator = ConstantEvaluator(_resolver, library, this);
    final type = resolveTypeRef((node.variables.type), library);
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
      topLevelVar.type = type;
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
    final returnType = resolveTypeRef((node.returnType), methodElement);
    methodElement.returnType = returnType;
    methodElement.type = FunctionTypeRef(
      returnType: returnType,
      typeParameters: methodElement.typeParameters,
      parameters: methodElement.parameters,
      isNullable: false,
    );
  }

  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) {
    final clazzElement = currentElementAs<ClassElementImpl>();
    final constructorName = node.name?.lexeme ?? '';

    if (clazzElement.getConstructor(constructorName) != null) {
      return;
    }

    final initializers = node.initializers;
    ConstructorElementRef? superConstructor;
    if (clazzElement.superType != null) {
      final superConstName =
          initializers.whereType<SuperConstructorInvocation>().map((e) => e.constructorName?.name).firstOrNull;
      final superClazz = clazzElement.superType;
      if (superClazz != null) {
        superConstructor = ConstructorElementRef(superClazz, superConstName ?? '');
      }
    }

    final constructorElement = ConstructorElementImpl(
      name: constructorName,
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

    // for (final initializer in initializers) {
    //   if (initializer is ConstructorFieldInitializer) {
    //     final field = clazzElement.getField(initializer.fieldName.name) as FieldElementImpl?;
    //     if (field != null) {
    //       field.setConstantComputeValue(() {
    //         return _evaluateConstant(initializer.expression, clazzElement.library);
    //       });
    //     }
    //   }
    // }

    final redirectedConstructor = node.redirectedConstructor;
    if (redirectedConstructor != null) {
      final redType = redirectedConstructor.type;
      final identifierRef = _resolver.resolveIdentifier(clazzElement.library, [
        if (redType.importPrefix != null) redType.importPrefix!.name.lexeme,
        redType.name2.lexeme,
      ]);
      final identifierLocation = _resolver.getDeclarationRef(
        identifierRef.topLevelTarget,
        constructorElement.library.src,
        importPrefix: identifierRef.importPrefix,
      );

      final resolvedType = NamedTypeRefImpl(identifierRef.name, identifierLocation!);
      constructorElement.returnType = resolvedType;
      constructorElement.redirectedConstructor = ConstructorElementRef(resolvedType, identifierRef.name);
    }
  }

  Constant? _evaluateConstant(Expression expression, LibraryElement library) {
    final constEvaluator = ConstantEvaluator(_resolver, library, this);
    return constEvaluator.evaluate(expression);
  }
}
