import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:lean_builder/src/element/builder/element_stack.dart';
import 'package:lean_builder/src/element/element.dart';
import 'package:lean_builder/src/graph/assets_graph.dart';
import 'package:lean_builder/src/graph/scan_results.dart';
import 'package:lean_builder/src/resolvers/constant/const_evaluator.dart';
import 'package:lean_builder/src/resolvers/constant/constant.dart';
import 'package:lean_builder/src/resolvers/resolver.dart';
import 'package:lean_builder/src/type/type_ref.dart';

class ElementBuilder extends UnifyingAstVisitor<void> with ElementStack {
  final Resolver resolver;

  final bool preResolveTopLevelMetadata;

  ElementBuilder(this.resolver, LibraryElement rootLibrary, {this.preResolveTopLevelMetadata = false}) {
    pushElement(rootLibrary);
  }

  @override
  void visitExtensionTypeDeclaration(ExtensionTypeDeclaration node) {
    final library = currentLibrary();
    if (library.hasElement(node.name.lexeme)) return;
    final extensionTypeElement = ExtensionTypeImpl(name: node.name.lexeme, library: library);

    library.addElement(extensionTypeElement);
    visitElementScoped(extensionTypeElement, () {
      node.documentationComment?.accept(this);
      node.typeParameters?.visitChildren(this);
      if (preResolveTopLevelMetadata) {
        node.metadata.accept(this);
        extensionTypeElement.didResolveMetadata = true;
      }
      for (final member in node.members) {
        if (member is! MethodDeclaration) {
          member.accept(this);
        }
      }
    });
    _resolveInterfaceTypeRefs(extensionTypeElement, implementsClause: node.implementsClause);
    extensionTypeElement.thisType = NamedTypeRefImpl(
      extensionTypeElement.name,
      library.buildDeclarationRef(extensionTypeElement.name, TopLevelIdentifierType.$class),
    );

    if (!preResolveTopLevelMetadata) {
      registerMetadataResolver(extensionTypeElement, node.metadata);
    }
  }

  @override
  void visitClassTypeAlias(ClassTypeAlias node) {
    final library = currentLibrary();
    if (library.hasElement(node.name.lexeme)) return;
    final clazzElement = ClassElementImpl(
      library: library,
      name: node.name.lexeme,
      hasAbstract: node.abstractKeyword != null,
      hasSealedKeyword: node.sealedKeyword != null,
      hasBase: node.baseKeyword != null,
      hasInterface: node.interfaceKeyword != null,
      isMixinClass: node.mixinKeyword != null,
      hasFinal: node.finalKeyword != null,
      isMixinApplication: true,
    );
    visitElementScoped(clazzElement, () {
      node.documentationComment?.accept(this);
      node.typeParameters?.visitChildren(this);
      if (preResolveTopLevelMetadata) {
        node.metadata.accept(this);
        clazzElement.didResolveMetadata = true;
      }
    });
    _resolveSuperTypeRef(clazzElement, node.superclass);
    _resolveInterfaceTypeRefs(clazzElement, withClause: node.withClause, implementsClause: node.implementsClause);
    library.addElement(clazzElement);

    if (!preResolveTopLevelMetadata) {
      registerMetadataResolver(clazzElement, node.metadata);
    }
  }

  void registerMetadataResolver(ElementImpl elm, NodeList<Annotation> meta) {
    elm.metadataResolveCallback = () {
      visitElementScoped(elm, () {
        meta.accept(this);
      });
    };
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
      node.documentationComment?.accept(this);
      node.typeParameters?.visitChildren(this);
      if (preResolveTopLevelMetadata) {
        node.metadata.accept(this);
        typeAliasElm.didResolveMetadata = true;
      }
    });
    final targetType = node.functionType != null ? node.functionType! : node.type;
    final type = resolveTypeRef((targetType), typeAliasElm);
    typeAliasElm.aliasedType = type;

    if (!preResolveTopLevelMetadata) {
      registerMetadataResolver(typeAliasElm, node.metadata);
    }
  }

  @override
  void visitFunctionTypeAlias(FunctionTypeAlias node) {
    final library = currentLibrary();
    if (library.hasElement(node.name.lexeme)) return;
    final funcElement = FunctionElementImpl(name: node.name.lexeme, enclosingElement: library);
    visitElementScoped(funcElement, () {
      node.documentationComment?.accept(this);
      node.typeParameters?.visitChildren(this);
      node.parameters.visitChildren(this);
      if (preResolveTopLevelMetadata) {
        node.metadata.accept(this);
        funcElement.didResolveMetadata = true;
      }
    });
    final typeAliasElm = TypeAliasElementImpl(name: node.name.lexeme, library: library);
    library.addElement(typeAliasElm);
    typeAliasElm.aliasedType = FunctionTypeRef(
      isNullable: false,
      parameters: funcElement.parameters,
      typeParameters: funcElement.typeParameters,
      returnType: resolveTypeRef(node.returnType, funcElement),
    );

    if (!preResolveTopLevelMetadata) {
      registerMetadataResolver(typeAliasElm, node.metadata);
    }
  }

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final library = currentLibrary();
    if (library.hasElement(node.name.lexeme)) return;
    final classElement = ClassElementImpl(
      name: node.name.lexeme,
      library: library,
      hasAbstract: node.abstractKeyword != null,
      hasSealedKeyword: node.sealedKeyword != null,
      hasBase: node.baseKeyword != null,
      hasFinal: node.finalKeyword != null,
      hasInterface: node.interfaceKeyword != null,
      isMixinClass: node.mixinKeyword != null,
      isMixinApplication: false,
    );
    library.addElement(classElement);

    visitElementScoped(classElement, () {
      node.documentationComment?.accept(this);
      node.typeParameters?.visitChildren(this);
      for (final member in node.members.whereType<FieldDeclaration>()) {
        member.accept(this);
      }
      if (preResolveTopLevelMetadata) {
        node.metadata.accept(this);
        classElement.didResolveMetadata = true;
      }
    });

    classElement.thisType = NamedTypeRefImpl(
      classElement.name,
      library.buildDeclarationRef(classElement.name, TopLevelIdentifierType.$class),
      typeArguments: classElement.typeParameters,
    );
    _resolveSuperTypeRef(classElement, node.extendsClause?.superclass);
    visitElementScoped(classElement, () {
      for (final constructor in node.members.whereType<ConstructorDeclaration>()) {
        constructor.accept(this);
      }
    });
    _resolveInterfaceTypeRefs(classElement, withClause: node.withClause, implementsClause: node.implementsClause);

    if (!preResolveTopLevelMetadata) {
      registerMetadataResolver(classElement, node.metadata);
    }
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
      node.documentationComment?.accept(this);
      node.typeParameters?.visitChildren(this);

      for (final member in node.members) {
        if (member is! MethodDeclaration) {
          member.accept(this);
        }
      }
      if (preResolveTopLevelMetadata) {
        node.metadata.accept(this);
        mixinElement.didResolveMetadata = true;
      }
    });
    mixinElement.thisType = NamedTypeRefImpl(
      mixinElement.name,
      libraryElement.buildDeclarationRef(mixinElement.name, TopLevelIdentifierType.$mixin),
      typeArguments: mixinElement.typeParameters,
    );
    _resolveInterfaceTypeRefs(mixinElement, implementsClause: node.implementsClause, onClause: node.onClause);

    if (!preResolveTopLevelMetadata) {
      registerMetadataResolver(mixinElement, node.metadata);
    }
  }

  @override
  void visitEnumDeclaration(EnumDeclaration node) {
    final library = currentLibrary();
    if (library.hasElement(node.name.lexeme)) return;

    final enumElement = EnumElementImpl(name: node.name.lexeme, library: library);
    library.addElement(enumElement);

    enumElement.thisType = NamedTypeRefImpl(
      enumElement.name,
      library.buildDeclarationRef(enumElement.name, TopLevelIdentifierType.$enum),
    );

    visitElementScoped(enumElement, () {
      node.documentationComment?.accept(this);
      node.typeParameters?.visitChildren(this);
      for (final member in node.members.whereType<FieldDeclaration>()) {
        member.accept(this);
      }
      for (final member in node.members.whereType<ConstructorDeclaration>()) {
        member.accept(this);
      }
      node.constants.accept(this);
      if (preResolveTopLevelMetadata) {
        node.metadata.accept(this);
        enumElement.didResolveMetadata = true;
      }
    });
    _resolveInterfaceTypeRefs(enumElement, implementsClause: node.implementsClause, withClause: node.withClause);

    if (!preResolveTopLevelMetadata) {
      registerMetadataResolver(enumElement, node.metadata);
    }
  }

  @override
  void visitEnumConstantDeclaration(EnumConstantDeclaration node) {
    final enumElement = currentElementAs<EnumElementImpl>();
    final fieldEle = FieldElementImpl(
      name: node.name.lexeme,
      isStatic: true,
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
    visitElementScoped(fieldEle, () {
      node.documentationComment?.accept(this);
    });
    final args = node.arguments;
    if (args != null) {
      fieldEle.setConstantComputeValue(() {
        final constEvaluator = ConstantEvaluator(resolver, enumElement.library, this);
        final enumNode = node.thisOrAncestorOfType<EnumDeclaration>()!;
        final constructorName = args.constructorSelector?.name;
        final constructor = enumNode.members.whereType<ConstructorDeclaration>().firstWhere(
          (e) => e.name?.lexeme == constructorName?.name,
          orElse: () => throw Exception('Could not find constructor'),
        );
        final constantObj = constEvaluator.evaluate(constructor) as ConstObjectImpl?;
        return constantObj?.mergeArgs(args.argumentList, constEvaluator);
      });
    }
    enumElement.addField(fieldEle);
    registerMetadataResolver(fieldEle, node.metadata);
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
    if (typename == TypeRef.neverType.name) return TypeRef.neverType;

    final typeArgs = <TypeRef>[];
    for (final typeArg in [...?annotation.typeArguments?.arguments]) {
      typeArgs.add(resolveTypeRef(typeArg, enclosingEle));
    }

    final importPrefix = annotation.importPrefix;
    final identifierLocation = resolver.getDeclarationRef(
      typename,
      enclosingEle.library.src,
      importPrefix: importPrefix?.name.lexeme,
    );

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
      fieldEle.initializer = variable.initializer;
      if (fieldEle.hasInitializer && fieldEle.isConst) {
        fieldEle.setConstantComputeValue(() {
          final constEvaluator = ConstantEvaluator(resolver, interfaceElement.library, this);
          return constEvaluator.evaluate(variable.initializer!);
        });
      }
      interfaceElement.addField(fieldEle);
      registerMetadataResolver(fieldEle, variable.metadata);
    }
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    print(node);
  }

  @override
  void visitAnnotation(Annotation node) {
    final currentElement = currentElementAs<ElementImpl>();
    final name = node.name;
    final identifier = resolver.resolveIdentifier(currentElement.library, [
      if (name is SimpleIdentifier) name.name,
      if (name is PrefixedIdentifier) ...[name.prefix.name, name.identifier.name],
    ]);

    final (lib, targetNode, decRef) = resolver.astNodeFor(identifier, currentElement.library);
    final constantEvaluator = ConstantEvaluator(resolver, lib, this);
    if (targetNode is ClassDeclaration || targetNode is ConstructorDeclaration) {
      final classDeclaration = targetNode.thisOrAncestorOfType<ClassDeclaration>()!;
      final className = classDeclaration.name.lexeme;
      final typeArgs = <TypeRef>[];
      for (final typeArg in [...?node.typeArguments?.arguments]) {
        typeArgs.add(resolveTypeRef(typeArg, currentElement));
      }
      final elem = ElementAnnotationImpl(
        type: NamedTypeRefImpl(className, decRef, typeArguments: typeArgs),
        declarationRef: decRef,
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
        final identifier = resolver.resolveIdentifier(lib, parts);
        final (_, _, declarationRef) = resolver.astNodeFor(identifier, lib);
        final typeArgs = <TypeRef>[];
        for (final typeArg in [...?initializer.typeArguments?.arguments]) {
          typeArgs.add(resolveTypeRef(typeArg, currentElement));
        }
        typeRef = NamedTypeRefImpl(identifier.topLevelTarget, declarationRef, typeArguments: typeArgs);
      }
      final elem = ElementAnnotationImpl(
        type: typeRef,
        declarationRef: decRef,
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
      node.documentationComment?.accept(this);
      node.functionExpression.typeParameters?.visitChildren(this);
      node.functionExpression.parameters?.visitChildren(this);
      if (preResolveTopLevelMetadata) {
        node.metadata.accept(this);
        funcElement.didResolveMetadata = true;
      }
    });
    final returnType = resolveTypeRef((node.returnType), funcElement);
    funcElement.returnType = returnType;
    funcElement.type = FunctionTypeRef(
      returnType: returnType,
      typeParameters: funcElement.typeParameters,
      parameters: funcElement.parameters,
      isNullable: false,
    );

    if (!preResolveTopLevelMetadata) {
      registerMetadataResolver(funcElement, node.metadata);
    }
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
        final constEvaluator = ConstantEvaluator(resolver, executableElement.library, this);
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
    final interfaceElement = constructorEle.enclosingElement as InterfaceElementImpl;
    final fields = interfaceElement.fields;
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
    final (lib, clazzNode as ClassDeclaration, _) = resolver.astNodeFor(ref, library);

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
        final constEvaluator = ConstantEvaluator(resolver, library, this);
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
    registerMetadataResolver(parameterElement, node.metadata);
    return parameterElement;
  }

  @override
  void visitTopLevelVariableDeclaration(TopLevelVariableDeclaration node) {
    final library = currentLibrary();
    final constantEvaluator = ConstantEvaluator(resolver, library, this);
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
      visitElementScoped(topLevelVar, () {
        node.documentationComment?.accept(this);
        if (preResolveTopLevelMetadata) {
          node.metadata.accept(this);
          topLevelVar.didResolveMetadata = true;
        }
      });
      if (!preResolveTopLevelMetadata) {
        registerMetadataResolver(topLevelVar, node.metadata);
      }
      library.addElement(topLevelVar);
    }
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    final interfaceElement = currentElementAs<InterfaceElementImpl>();
    final name = node.name.lexeme;
    MethodElementImpl methodElement = MethodElementImpl(
      isStatic: node.isStatic,
      name: name,
      enclosingElement: interfaceElement,
      isAbstract: node.isAbstract,
      isAsynchronous: node.body.isAsynchronous,
      isExternal: node.externalKeyword != null,
      isGenerator: node.body.isGenerator,
      isOperator: node.isOperator,
      isSynchronous: node.body.isSynchronous,
    );

    final accessKeyword = node.propertyKeyword;
    if (accessKeyword != null) {
      methodElement = methodElement.toPropertyAccessorElement(
        isGetter: accessKeyword.keyword == Keyword.GET,
        isSetter: accessKeyword.keyword == Keyword.SET,
      );
    }

    interfaceElement.addMethod(methodElement);
    visitElementScoped(methodElement, () {
      node.documentationComment?.accept(this);
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

    registerMetadataResolver(methodElement, node.metadata);
  }

  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) {
    final interfaceElement = currentElementAs<InterfaceElementImpl>();
    final constructorName = node.name?.lexeme ?? '';
    if (interfaceElement.hasConstructor(constructorName)) return;

    final initializers = node.initializers;
    ConstructorElementRef? superConstructor;

    if (interfaceElement.superType != null) {
      final invocations = initializers.whereType<SuperConstructorInvocation>();
      final superConstName = invocations.map((e) => e.constructorName?.name).firstOrNull;
      final superClazz = interfaceElement.superType;
      if (superClazz != null) {
        superConstructor = ConstructorElementRef(superClazz, superConstName ?? '');
      }
    }

    final constructorElement = ConstructorElementImpl(
      name: constructorName,
      enclosingElement: interfaceElement,
      isConst: node.constKeyword != null,
      isFactory: node.factoryKeyword != null,
      isGenerator: node.body.isGenerator,
      superConstructor: superConstructor,
    );

    interfaceElement.addConstructor(constructorElement);
    constructorElement.returnType = interfaceElement.thisType;

    visitElementScoped(constructorElement, () {
      node.documentationComment?.accept(this);
      node.parameters.visitChildren(this);
    });

    final redirectedConstructor = node.redirectedConstructor;
    if (redirectedConstructor != null) {
      final redType = redirectedConstructor.type;
      final identifierRef = resolver.resolveIdentifier(interfaceElement.library, [
        if (redType.importPrefix != null) redType.importPrefix!.name.lexeme,
        redType.name2.lexeme,
      ]);

      final declarationRef = resolver.getDeclarationRef(
        identifierRef.topLevelTarget,
        constructorElement.library.src,
        importPrefix: identifierRef.importPrefix,
      );

      final resolvedType = NamedTypeRefImpl(identifierRef.name, declarationRef);
      constructorElement.returnType = resolvedType;
      constructorElement.redirectedConstructor = ConstructorElementRef(resolvedType, identifierRef.name);
    }
    registerMetadataResolver(constructorElement, node.metadata);
  }

  @override
  void visitComment(Comment node) {
    final buffer = StringBuffer();
    for (var i = 0; i < node.tokens.length; i++) {
      buffer.write(node.tokens[i].lexeme);
      if (i < node.tokens.length - 1) {
        buffer.writeln();
      }
    }
    currentElementAs<ElementImpl>().documentationComment = buffer.toString();
  }
}
