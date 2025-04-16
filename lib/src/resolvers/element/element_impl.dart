part of 'element.dart';

typedef ConstantValueCompute = Constant? Function();

abstract class ElementImpl implements Element {
  @override
  String toString() => name;

  @override
  String get identifier => '${library.src}#$name';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Element && runtimeType == other.runtimeType && identifier == other.identifier;

  @override
  int get hashCode => name.hashCode ^ library.hashCode;

  @override
  List<ElementAnnotation> get metadata {
    return _metadata;
  }

  final List<ElementAnnotation> _metadata = [];

  void addMetadata(ElementAnnotation annotation) {
    _metadata.add(annotation);
  }
}

class LibraryElementImpl extends ElementImpl implements LibraryElement {
  LibraryElementImpl(this.resolver, this.compilationUnit, {required this.src});

  @override
  final CompilationUnit compilationUnit;

  @override
  final ElementResolver resolver;

  final List<Element> resolvedElements = [];

  bool _didResolveDirectives = false;

  bool _didResolveAllTypeAliases = false;

  bool _didResolveAllClasses = false;

  bool _didResolveAllMixins = false;

  bool _didResolveAllEnums = false;

  bool _didResolveAllFunctions = false;

  void addElement(Element element) {
    resolvedElements.add(element);
  }

  @override
  late final String name = src.shortPath.pathSegments.last;

  @override
  final AssetSrc src;

  @override
  Null get enclosingElement => null;

  @override
  LibraryElement get library => this;

  List<E> _elementsOfType<E extends Element>() {
    return List<E>.unmodifiable(resolvedElements.whereType<E>());
  }

  @override
  List<ClassElementImpl> get classes {
    if (!_didResolveAllClasses) {
      resolver.resolveClasses(this);
      _didResolveAllClasses = true;
    }
    return _elementsOfType<ClassElementImpl>();
  }

  @override
  List<MixinElementImpl> get mixins {
    if (!_didResolveAllMixins) {
      resolver.resolveMixins(this);
      _didResolveAllMixins = true;
    }
    return _elementsOfType<MixinElementImpl>();
  }

  @override
  List<EnumElementImpl> get enums {
    if (!_didResolveAllEnums) {
      resolver.resolveEnums(this);
      _didResolveAllEnums = true;
    }
    return _elementsOfType<EnumElementImpl>();
  }

  @override
  List<FunctionElement> get functions {
    if (!_didResolveAllFunctions) {
      resolver.resolveFunctions(this);
      _didResolveAllFunctions = true;
    }
    return _elementsOfType<FunctionElement>();
  }

  @override
  List<TypeAliasElement> get typeAliases {
    if (!_didResolveAllTypeAliases) {
      resolver.resolveTypeAliases(this);
      _didResolveAllTypeAliases = true;
    }
    return _elementsOfType<TypeAliasElement>();
  }

  bool hasElement(String name) {
    return resolvedElements.any((e) => e.name == name);
  }

  @override
  ClassElementImpl? getClass(String name) {
    if (_didResolveAllClasses || hasElement(name)) {
      return _elementsOfType<ClassElementImpl>().firstWhereOrNull((e) => e.name == name);
    }
    resolver.resolveClasses(this, predicate: (e) => e.name.lexeme == name);
    return _elementsOfType<ClassElementImpl>().firstWhereOrNull((e) => e.name == name);
  }

  @override
  Element? getElement(String name) {
    return resolvedElements.firstWhereOrNull((e) => e.name == name);
  }

  @override
  MixinElementImpl? getMixin(String name) {
    if (_didResolveAllMixins || hasElement(name)) {
      return _elementsOfType<MixinElementImpl>().firstWhereOrNull((e) => e.name == name);
    }
    resolver.resolveMixins(this, predicate: (e) => e.name.lexeme == name);
    return _elementsOfType<MixinElementImpl>().firstWhereOrNull((e) => e.name == name);
  }

  @override
  EnumElementImpl? getEnum(String name) {
    if (_didResolveAllEnums || hasElement(name)) {
      return _elementsOfType<EnumElementImpl>().firstWhereOrNull((e) => e.name == name);
    }
    resolver.resolveEnums(this, predicate: (e) => e.name.lexeme == name);
    return _elementsOfType<EnumElementImpl>().firstWhereOrNull((e) => e.name == name);
  }

  @override
  TypeAliasElement? getTypeAlias(String name) {
    if (_didResolveAllTypeAliases || hasElement(name)) {
      return _elementsOfType<TypeAliasElement>().firstWhereOrNull((e) => e.name == name);
    }
    resolver.resolveTypeAliases(this, predicate: (e) => e.name.lexeme == name);
    return _elementsOfType<TypeAliasElement>().firstWhereOrNull((e) => e.name == name);
  }

  @override
  FunctionElement? getFunction(String name) {
    if (_didResolveAllFunctions || hasElement(name)) {
      return _elementsOfType<FunctionElement>().firstWhereOrNull((e) => e.name == name);
    }
    resolver.resolveFunctions(this, predicate: (e) => e.name.lexeme == name);
    return _elementsOfType<FunctionElement>().firstWhereOrNull((e) => e.name == name);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other && other is LibraryElement && runtimeType == other.runtimeType && src.id == other.src.id;

  @override
  int get hashCode => src.id.hashCode;

  @override
  DeclarationRef buildLocation(String identifier, TopLevelIdentifierType type) {
    return DeclarationRef(
      identifier: identifier,
      srcId: src.id,
      srcUri: resolver.uriForAsset(src.id),
      providerId: src.id,
      type: type,
    );
  }

  @override
  List<DirectiveElement> get directives {
    if (!_didResolveDirectives) {
      resolver.resolveDirectives(this);
      _didResolveDirectives = true;
    }
    return _elementsOfType<DirectiveElement>();
  }
}

mixin TypeParameterizedElementMixin on Element implements TypeParameterizedElement {
  final List<TypeParameterTypeRef> _typeParameters = [];

  @override
  List<TypeParameterTypeRef> get typeParameters => _typeParameters;

  void addTypeParameter(TypeParameterTypeRef typeParameter) {
    _typeParameters.add(typeParameter);
  }

  List<TypeParameterTypeRef> get allTypeParameters {
    final List<TypeParameterTypeRef> allTypeParameters = [];
    allTypeParameters.addAll(typeParameters);
    if (enclosingElement is TypeParameterizedElementMixin) {
      allTypeParameters.addAll((enclosingElement as TypeParameterizedElementMixin).allTypeParameters);
    }
    return allTypeParameters;
  }
}

class InterfaceElementImpl extends ElementImpl with TypeParameterizedElementMixin implements InterfaceElement {
  final List<NamedTypeRef> _mixins = [];
  final List<NamedTypeRef> _interfaces = [];
  final List<NamedTypeRef> _superConstrains = [];
  final List<MethodElement> _methods = [];

  bool _didResolveMethods = false;
  final List<FieldElement> _fields = [];

  NamedTypeRef? _superType;
  NamedTypeRef? _thisType;

  InterfaceElementImpl({required this.name, required this.library});

  @override
  List<FieldElement> get fields => _fields;

  @override
  List<MethodElement> get methods {
    if (!_didResolveMethods) {
      library.resolver.resolveMethods(this);
      _didResolveMethods = true;
    }
    return _methods;
  }

  @override
  List<TypeRef> get interfaces => _interfaces;

  @override
  List<TypeRef> get mixins => _mixins;

  @override
  List<TypeParameterTypeRef> get typeParameters => _typeParameters;

  void addMixin(NamedTypeRef mixin) {
    _mixins.add(mixin);
  }

  void addInterface(NamedTypeRef interface) {
    _interfaces.add(interface);
  }

  void addMethod(MethodElement method) {
    _methods.add(method);
  }

  void addField(FieldElement field) {
    _fields.add(field);
  }

  @override
  List<TypeRef> get allSuperTypes => throw UnimplementedError();

  @override
  final String name;

  @override
  final LibraryElementImpl library;

  @override
  Element? get enclosingElement => library;

  set superType(NamedTypeRef? value) {
    _superType = value;
  }

  @override
  NamedTypeRef? get superType => _superType;

  set thisType(NamedTypeRef? value) {
    _thisType = value;
  }

  @override
  NamedTypeRef get thisType => _thisType!;

  @override
  List<PropertyAccessorElement> get accessors => throw UnimplementedError();

  @override
  FieldElement? getField(String name) {
    for (final field in _fields) {
      if (field.name == name) {
        return field;
      }
    }
    return null;
  }

  @override
  MethodElement? getMethod(String name) {
    if (_didResolveMethods) {
      for (final method in _methods) {
        if (method.name == name) {
          return method;
        }
      }
      return null;
    }
    library.resolver.resolveMethods(
      this,
      predicate: (m) {
        return m.name.lexeme == name;
      },
    );

    for (final method in _methods) {
      if (method.name == name) {
        return method;
      }
    }
    return null;
  }

  @override
  TypeRef instantiate(NamedTypeRef typeRef) {
    var substitution = Substitution.fromPairs(typeParameters, typeRef.typeArguments);
    return substitution.substituteType(thisType, isNullable: typeRef.isNullable);
  }
}

abstract class VariableElementImpl extends ElementImpl implements VariableElement {
  VariableElementImpl({
    required this.name,
    required this.enclosingElement,
    required this.hasImplicitType,
    required this.isConst,
    required this.isFinal,
    required this.isLate,
    required this.isStatic,
  });

  @override
  final Element enclosingElement;

  @override
  LibraryElement get library => enclosingElement.library;

  @override
  final bool hasImplicitType;
  @override
  final bool isConst;
  @override
  final bool isFinal;
  @override
  final bool isLate;
  @override
  final bool isStatic;
  @override
  final String name;

  @override
  Expression? get initializer => _initializer;

  Expression? _initializer;

  set initializer(Expression? initializer) {
    _initializer = initializer;
  }

  ConstantValueCompute? constantValueCompute;

  void setConstantComputeValue(ConstantValueCompute? constantValueCompute) {
    this.constantValueCompute = constantValueCompute;
  }

  @override
  Constant? get constantValue => _constantValue ??= constantValueCompute?.call();

  Constant? _constantValue;

  @override
  TypeRef get type => _type!;

  TypeRef? _type;

  set type(TypeRef type) {
    _type = type;
  }
}

class TopLevelVariableElementImpl extends VariableElementImpl implements TopLevelVariableElement {
  TopLevelVariableElementImpl({
    required super.name,
    required super.enclosingElement,
    required super.hasImplicitType,
    required super.isConst,
    required super.isFinal,
    required super.isLate,
    required this.isExternal,
  }) : super(isStatic: false);

  @override
  final bool isExternal;

  @override
  LibraryElement get library => enclosingElement.library;
}

class FieldElementImpl extends VariableElementImpl implements ClassMemberElement, FieldElement {
  FieldElementImpl({
    required super.isStatic,
    required super.name,
    required super.enclosingElement,
    required super.hasImplicitType,
    required super.isConst,
    required super.isFinal,
    required super.isLate,
    required this.isAbstract,
    required this.isCovariant,
    required this.isEnumConstant,
    required this.isExternal,
    required this.type,
  });

  @override
  final bool isAbstract;
  @override
  final bool isCovariant;
  @override
  final bool isEnumConstant;
  @override
  final bool isExternal;

  @override
  LibraryElement get library => enclosingElement.library;

  @override
  final TypeRef type;
}

class ParameterElementImpl extends VariableElementImpl implements ParameterElement, VariableElement {
  ParameterElementImpl({
    required super.name,
    required super.enclosingElement,
    required super.hasImplicitType,
    required super.isConst,
    required super.isFinal,
    required super.isLate,
    required this.isCovariant,
    required this.isInitializingFormal,
    required this.isNamed,
    required this.isOptional,
    required this.isOptionalNamed,
    required this.isOptionalPositional,
    required this.isPositional,
    required this.isRequired,
    required this.isRequiredPositional,
    required this.isRequiredNamed,
    required this.isSuperFormal,
  }) : super(isStatic: false);

  @override
  LibraryElement get library => enclosingElement.library;

  @override
  String? get defaultValueCode => constantValue?.toString();

  @override
  bool get hasDefaultValue => constantValueCompute != null;

  @override
  final bool isCovariant;

  @override
  final bool isInitializingFormal;

  @override
  final bool isNamed;

  @override
  final bool isOptional;

  @override
  final bool isOptionalNamed;

  @override
  final bool isOptionalPositional;

  @override
  final bool isPositional;
  @override
  final bool isRequired;

  @override
  final bool isRequiredPositional;

  @override
  final bool isRequiredNamed;

  @override
  final bool isSuperFormal;

  @override
  List<ParameterElement> get parameters {
    final type = this.type;
    if (type is FunctionTypeRef) {
      return type.parameters;
    }
    return [];
  }

  @override
  List<TypeParameterTypeRef> get typeParameters {
    final type = this.type;
    if (type is FunctionTypeRef) {
      return type.typeParameters;
    }
    return [];
  }
}

class ClassElementImpl extends InterfaceElementImpl implements ClassElement {
  ClassElementImpl({
    required super.name,
    required super.library,
    required this.isAbstract,
    required this.isBase,
    required this.isFinal,
    required this.isInterface,
    required this.isMixinApplication,
    required this.isMixinClass,
    required this.isSealed,
  });

  @override
  List<ConstructorElement> get constructors => _constructors;

  final List<ConstructorElement> _constructors = [];

  void addConstructor(ConstructorElement constructor) {
    _constructors.add(constructor);
  }

  @override
  ConstructorElement? getConstructor(String name) {
    return _constructors.firstWhereOrNull((e) => e.name == name);
  }

  @override
  ConstructorElement? get unnamedConstructor => _constructors.firstWhereOrNull((e) => e.name.isEmpty);

  @override
  final bool isAbstract;

  @override
  final bool isBase;

  @override
  bool get isConstructable => !isAbstract && !isSealed;

  @override
  final bool isFinal;

  @override
  final bool isInterface;

  @override
  final bool isMixinApplication;

  @override
  final bool isMixinClass;

  @override
  final bool isSealed;
}

class EnumElementImpl extends InterfaceElementImpl implements EnumElement {
  EnumElementImpl({required super.name, required super.library});
}

class MixinElementImpl extends InterfaceElementImpl implements MixinElement {
  MixinElementImpl({required super.name, required super.library, required this.isBase});

  @override
  final bool isBase;

  @override
  List<NamedTypeRef> get superclassConstraints => _superConstrains;

  void addSuperConstrain(NamedTypeRef superConstrains) {
    _superConstrains.add(superConstrains);
  }
}

class TypeAliasElementImpl extends ElementImpl with TypeParameterizedElementMixin implements TypeAliasElement {
  TypeAliasElementImpl({required this.name, required this.library});

  @override
  final String name;

  @override
  final LibraryElement library;

  @override
  Element get enclosingElement => library;

  @override
  TypeRef get aliasedType {
    return _aliasedType!;
  }

  TypeRef? _aliasedType;

  set aliasedType(TypeRef? aliasedType) {
    _aliasedType = aliasedType;
  }

  @override
  TypeRef instantiate(NamedTypeRef typeRef) {
    var substitution = Substitution.fromPairs(typeParameters, typeRef.typeArguments);
    return substitution.substituteType(aliasedType, isNullable: typeRef.isNullable);
  }
}
