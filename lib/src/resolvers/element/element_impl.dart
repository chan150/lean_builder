part of 'element.dart';

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
  LibraryElementImpl(this._resolver, this.compilationUnit, {required this.src});

  final ElementResolver _resolver;
  final CompilationUnit compilationUnit;
  final List<Element> _resolvedElements = [];

  void addElement(Element element) {
    _resolvedElements.add(element);
  }

  @override
  late final String name = _resolver.uriForAsset(srcId).pathSegments.last;

  @override
  final AssetSrc src;

  @override
  String get srcId => src.id;

  @override
  Null get enclosingElement => null;

  @override
  LibraryElement get library => this;

  @override
  List<Element> get resolvedElements => List.unmodifiable(_resolvedElements);

  @override
  Iterable<ClassElementImpl> get classes => resolvedElements.whereType<ClassElementImpl>();

  @override
  Iterable<MixinElementImpl> get mixins => resolvedElements.whereType<MixinElementImpl>();

  @override
  Iterable<EnumElementImpl> get enums => resolvedElements.whereType<EnumElementImpl>();

  @override
  Iterable<FunctionElement> get functions => resolvedElements.whereType<FunctionElement>();

  @override
  ClassElementImpl? getClass(String name) => classes.firstWhereOrNull((e) => e.name == name);

  @override
  InterfaceElement? getInterfaceElement(String name) {
    return resolvedElements.whereType<InterfaceElement>().firstWhereOrNull((e) => e.name == name);
  }

  @override
  Element? getElement(String name) {
    return resolvedElements.firstWhereOrNull((e) => e.name == name);
  }

  @override
  MixinElementImpl? getMixin(String name) {
    return mixins.firstWhereOrNull((e) => e.name == name);
  }

  @override
  EnumElementImpl? getEnum(String name) {
    return enums.firstWhereOrNull((e) => e.name == name);
  }

  @override
  TypeAliasElement? getTypeAlias(String name) {
    return typeAliases.firstWhereOrNull((e) => e.name == name);
  }

  @override
  FunctionElement? getFunction(String name) {
    return functions.firstWhereOrNull((e) => e.name == name);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other && other is LibraryElement && runtimeType == other.runtimeType && src.id == other.src.id;

  @override
  int get hashCode => src.id.hashCode;

  @override
  Iterable<TypeAliasElement> get typeAliases => resolvedElements.whereType<TypeAliasElement>();

  @override
  IdentifierLocation identifierLocationOf(String identifier, TopLevelIdentifierType type) {
    return IdentifierLocation(
      identifier: identifier,
      srcId: srcId,
      srcUri: _resolver.uriForAsset(srcId),
      providerId: srcId,
      type: type,
      importingLibrary: src,
    );
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

// abstract class InstanceElementImpl extends InstanceElement implements TypeParameterizedElement {
//   @override
//   List<PropertyAccessorElement> get accessors;
//
//   @override
//   List<FieldElement> get fields;
//
//   @override
//   List<MethodElement> get methods;
//
//   @override
//   DartType get thisType;
// }

class InterfaceElementImpl extends ElementImpl with TypeParameterizedElementMixin implements InterfaceElement {
  final List<NamedTypeRef> _mixins = [];
  final List<NamedTypeRef> _interfaces = [];
  final List<NamedTypeRef> _superConstrains = [];
  final List<MethodElement> _methods = [];
  final List<FieldElement> _fields = [];

  NamedTypeRef? _superType;
  NamedTypeRef? _thisType;

  InterfaceElementImpl({required this.name, required this.library});

  @override
  List<FieldElement> get fields => _fields;

  @override
  List<MethodElement> get methods => _methods;

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
  final LibraryElement library;

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

  Constant? Function()? computeConstantValue;

  void setConstantComputeValue(Constant? Function()? computeConstantValue) {
    this.computeConstantValue = computeConstantValue;
  }

  @override
  Constant? get constantValue => _constantValue ??= computeConstantValue?.call();

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
  bool get hasDefaultValue => computeConstantValue != null;

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
    // if (type is FunctionType) {
    //   return type.parameters;
    // }
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
  ClassElementImpl({required super.name, required super.library});

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
}

class EnumElementImpl extends InterfaceElementImpl implements EnumElement {
  EnumElementImpl({required super.name, required super.library});
}

class MixinElementImpl extends InterfaceElementImpl implements MixinElement {
  MixinElementImpl({required super.name, required super.library});

  @override
  List<TypeRef> get superclassConstraints => _superConstrains;

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
