import 'dart:async';
import 'dart:developer';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:code_genie/src/resolvers/const/const_evaluator.dart';
import 'package:code_genie/src/resolvers/const/constant.dart';
import 'package:code_genie/src/resolvers/element/element.dart';
import 'package:code_genie/src/resolvers/element_resolver.dart';
import 'package:code_genie/src/resolvers/type/type_ref.dart';
import 'package:code_genie/src/resolvers/visitor/element_stack.dart';
import 'package:code_genie/src/scanner/scan_results.dart';

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
  void visitExtensionTypeDeclaration(ExtensionTypeDeclaration node) {
    final library = currentLibrary();
    if (library.getClass(node.name.lexeme) != null) {
      return;
    }
    final clazzElement = ClassElementImpl(name: node.name.lexeme, library: library);
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
    _resolveInterfaces(clazzElement, implementsClause: node.implementsClause);
    clazzElement.thisType = NamedTypeRef(
      clazzElement.name,
      library.identifierLocationOf(clazzElement.name, TopLevelIdentifierType.$class),
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
    final resolvedSuperType = resolveTypeRef(type, element);
    assert(resolvedSuperType is NamedTypeRef, 'Super type must be an interface type ${resolvedSuperType.runtimeType}');
    element.superType = resolvedSuperType as NamedTypeRef;
  }

  void _resolveInterfaces(
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
    if (library.getTypeAlias(node.name.lexeme) != null) {
      return;
    }
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
    if (library.getTypeAlias(node.name.lexeme) != null) {
      return;
    }
    final funcElement = FunctionElementImpl(name: node.name.lexeme, enclosingElement: library);
    visitElementScoped(funcElement, () {
      node.typeParameters?.visitChildren(this);
      node.parameters.visitChildren(this);
    });
    final typeAliasElm = TypeAliasElementImpl(name: node.name.lexeme, library: library);
    library.addElement(typeAliasElm);
    typeAliasElm.aliasedType = FunctionTypeRef(
      node.name.lexeme,
      isNullable: false,
      parameters: funcElement.parameters,
      typeParameters: funcElement.typeParameters,
      returnType: resolveTypeRef(node.returnType, funcElement),
    );
  }

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final libraryElement = currentLibrary();
    if (libraryElement.getClass(node.name.lexeme) != null) {
      return;
    }
    final classElement = ClassElementImpl(name: node.name.lexeme, library: libraryElement);
    libraryElement.addElement(classElement);

    visitElementScoped(classElement, () {
      node.typeParameters?.visitChildren(this);
      node.metadata.accept(this);
      for (final field in node.members.whereType<FieldDeclaration>()) {
        field.accept(this);
      }
      // for (final method in node.members.whereType<MethodDeclaration>()) {
      //   method.accept(this);
      // }
    });

    classElement.thisType = NamedTypeRef(
      classElement.name,
      libraryElement.identifierLocationOf(classElement.name, TopLevelIdentifierType.$class),
      typeArguments: classElement.typeParameters,
    );

    _resolveSuperType(classElement, node.extendsClause?.superclass);

    visitElementScoped(classElement, () {
      for (final constructor in node.members.whereType<ConstructorDeclaration>()) {
        constructor.accept(this);
      }
    });
    if (classElement.name == 'ProxyWidget') {
      print(classElement);
    }
    _resolveInterfaces(classElement, withClause: node.withClause, implementsClause: node.implementsClause);
  }

  @override
  void visitMixinDeclaration(MixinDeclaration node) {
    final libraryElement = currentLibrary();
    final MixinElementImpl mixinElement;
    if (libraryElement.getMixin(node.name.lexeme) != null) {
      return;
    } else {
      mixinElement = MixinElementImpl(name: node.name.lexeme, library: libraryElement);
      libraryElement.addElement(mixinElement);
    }

    visitElementScoped(mixinElement, () {
      node.typeParameters?.visitChildren(this);
    });
    mixinElement.thisType = NamedTypeRef(
      mixinElement.name,
      libraryElement.identifierLocationOf(mixinElement.name, TopLevelIdentifierType.$mixin),
      typeArguments: mixinElement.typeParameters,
    );
    _resolveInterfaces(mixinElement, implementsClause: node.implementsClause, onClause: node.onClause);
  }

  @override
  void visitEnumDeclaration(EnumDeclaration node) {
    final libraryElement = currentLibrary();
    final EnumElementImpl enumElement;
    if (libraryElement.getEnum(node.name.lexeme) != null) {
      return;
    } else {
      enumElement = EnumElementImpl(name: node.name.lexeme, library: libraryElement);
      libraryElement.addElement(enumElement);
    }
    enumElement.thisType = NamedTypeRef(
      enumElement.name,
      libraryElement.identifierLocationOf(enumElement.name, TopLevelIdentifierType.$enum),
    );
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
    // libraryElement.addElement(funcEle);
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

  Element resolveTopLevelElement(IdentifierRef identifier, LibraryElement enclosingLibrary) {
    try {
      final (library, decNode) = _resolver.astNodeFor(identifier, enclosingLibrary);
      Element? decEle = library.getElement(identifier.name);
      if (decEle != null) {
        return decEle;
      }
      visitElementScoped(library, () => decNode.accept(this));
      decEle = library.getElement(identifier.name);
      if (decEle == null) {
        log('Element $identifier not found in ${library.src.uri}', stackTrace: StackTrace.current);
      }
      assert(decEle != null, 'Element $identifier could not be resolved ${library.src.uri}');
      return decEle!;
    } catch (e) {
      rethrow;
    }
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
      return resolveNamedType(typeAnno, enclosingEle);
    } else if (typeAnno is GenericFunctionType) {
      return resolveFunctionType(typeAnno, FunctionElementImpl(name: 'Function', enclosingElement: enclosingEle));
    }
    return TypeRef.invalidType;
  }

  FunctionTypeRef resolveFunctionType(GenericFunctionType typeAnnotation, FunctionElement funcElement) {
    visitElementScoped(funcElement, () {
      typeAnnotation.typeParameters?.visitChildren(this);
      typeAnnotation.parameters.visitChildren(this);
    });
    return FunctionTypeRef(
      funcElement.name,
      returnType: resolveTypeRef(typeAnnotation.returnType, funcElement),
      typeParameters: funcElement.typeParameters,
      parameters: funcElement.parameters,
      isNullable: typeAnnotation.question != null,
    );
  }

  TypeRef resolveNamedType(NamedType annotation, Element enclosingEle) {
    final typename = annotation.name2.lexeme;

    if (TypeRef.isNever(typename)) return TypeRef.neverType;
    if (TypeRef.isDynamic(typename)) return TypeRef.dynamicType;
    if (TypeRef.isVoid(typename)) return TypeRef.voidType;

    final typeArgs = <TypeRef>[];
    for (final typeArg in [...?annotation.typeArguments?.arguments]) {
      typeArgs.add(resolveTypeRef(typeArg, enclosingEle));
    }

    final identifierLocation = _resolver.graph.getIdentifierLocation(
      typename,
      enclosingEle.library.src,
      importPrefix: annotation.importPrefix?.name.lexeme,
    );
    assert(
      identifierLocation != null,
      'could not find identifier $annotation in ${_resolver.graph.uriForAsset(enclosingEle.library.srcId)}',
    );
    return NamedTypeRef(
      typename,
      identifierLocation!,
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
    libraryElement.addElement(funcElement);
    visitElementScoped(funcElement, () {
      node.functionExpression.typeParameters?.visitChildren(this);
      node.functionExpression.parameters?.visitChildren(this);
    });
    final returnType = resolveTypeRef((node.returnType), funcElement);
    funcElement.returnType = returnType;
    funcElement.type = FunctionTypeRef(
      funcElement.name,
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

  (TypeRef, Expression?) _resolveSuperParam({
    required IdentifierRef ref,
    required LibraryElement library,
    required String constructorName,
    required SuperFormalParameter superParam,
  }) {
    final (lib, clazzNode as ClassDeclaration) = _resolver.astNodeFor(ref, library);

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

    (TypeRef, Expression?) buildParam(FormalParameter param, LibraryElement lib) {
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
      ref: IdentifierRef(superConstRef.classType.name, src: superConstRef.classType.src),
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
    print('$superType $name');

    // final parameterElement = _buildParameter(node, constructorEle, isSuperFormal: true, type: superParam.type);
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
      methodElement.name,
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
    //
    final initializers = node.initializers;
    ConstructorElementRef? superConstructor;
    if (clazzElement.superType != null) {
      final superConstName =
          initializers.whereType<SuperConstructorInvocation>().map((e) => e.constructorName?.name).firstOrNull;
      final superClazz = clazzElement.superType as NamedTypeRef?;
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
      final IdentifierRef identifierRef;
      final type = redirectedConstructor.type;
      final prefix = type.importPrefix?.name.lexeme;
      if (prefix == null) {
        identifierRef = IdentifierRef(type.name2.lexeme);
      } else {
        final importPrefixes = _resolver.graph.importPrefixesOf(currentLibrary().srcId);
        final isImportPrefix = importPrefixes.contains(prefix);
        if (isImportPrefix) {
          identifierRef = IdentifierRef(type.name2.lexeme, importPrefix: prefix);
        } else {
          identifierRef = IdentifierRef(prefix);
        }
      }

      final identifierSrc = _resolver.graph.getIdentifierLocation(
        identifierRef.name,
        constructorElement.library.src,
        importPrefix: identifierRef.importPrefix,
      );

      final resolvedType = NamedTypeRef(constructorName, identifierSrc!, isNullable: false, typeArguments: []);
      constructorElement.returnType = resolvedType;
      constructorElement.redirectedConstructor = ConstructorElementRef(
        resolvedType,
        redirectedConstructor.name?.name ?? '',
      );
    }
  }

  Constant? _evaluateConstant(Expression expression, LibraryElement library) {
    final constEvaluator = ConstantEvaluator(_resolver, library, this);
    return constEvaluator.evaluate(expression);
  }
}
