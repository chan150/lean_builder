part of 'element.dart';

abstract class ExecutableElementImpl extends ElementImpl
    with TypeParameterizedElementMixin
    implements ExecutableElement {
  ExecutableElementImpl({
    required this.name,
    required this.isAbstract,
    required this.isAsynchronous,
    required this.isExternal,
    required this.isGenerator,
    required this.isOperator,
    required this.isStatic,
    required this.isSynchronous,
    required this.enclosingElement,
  });

  @override
  bool get hasImplicitReturnType => returnType == TypeRef.invalidType;

  @override
  final String name;

  @override
  final bool isAbstract;

  @override
  final bool isAsynchronous;

  @override
  final bool isExternal;

  @override
  final bool isGenerator;

  @override
  final bool isOperator;

  @override
  final bool isStatic;

  @override
  final bool isSynchronous;

  @override
  final Element enclosingElement;

  @override
  LibraryElement get library => enclosingElement.library;

  @override
  List<ParameterElement> get parameters => _parameters;

  TypeRef? _returnType;

  @override
  TypeRef get returnType => _returnType!;

  @override
  ParameterElement? getParameter(String name) {
    for (final parameter in _parameters) {
      if (parameter.name == name) {
        return parameter;
      }
    }
    return null;
  }

  set returnType(TypeRef type) {
    _returnType = type;
  }

  @override
  FunctionTypeRef get type => _type!;

  final List<ParameterElement> _parameters = [];
  FunctionTypeRef? _type;

  void addParameter(ParameterElement parameter) {
    _parameters.add(parameter);
  }

  set type(FunctionTypeRef type) {
    _type = type;
  }

  @override
  TypeRef instantiate(NamedTypeRef typeRef) {
    var substitution = Substitution.fromPairs(typeParameters, typeRef.typeArguments);
    return substitution.substituteType(type, isNullable: typeRef.isNullable);
  }
}

class FunctionElementImpl extends ExecutableElementImpl implements FunctionElement {
  FunctionElementImpl({
    required super.name,
    super.isAbstract = false,
    super.isAsynchronous = false,
    super.isExternal = false,
    super.isGenerator = false,
    super.isOperator = false,
    super.isStatic = false,
    super.isSynchronous = false,
    required super.enclosingElement,
  });

  @override
  bool get isEntryPoint => name == FunctionElement.kMainFunctionName;
}

class MethodElementImpl extends ExecutableElementImpl implements MethodElement {
  MethodElementImpl({
    required super.name,
    required super.isAbstract,
    required super.isAsynchronous,
    required super.isExternal,
    required super.isGenerator,
    required super.isOperator,
    required super.isStatic,
    required super.isSynchronous,
    required super.enclosingElement,
  });

  PropertyAccessorElementImpl toPropertyAccessorElement({required bool isGetter, required bool isSetter}) {
    return PropertyAccessorElementImpl(
      name: name,
      isAbstract: isAbstract,
      isAsynchronous: isAsynchronous,
      isExternal: isExternal,
      isGenerator: isGenerator,
      isOperator: isOperator,
      isStatic: isStatic,
      isSynchronous: isSynchronous,
      enclosingElement: enclosingElement,
      isGetter: isGetter,
      isSetter: isSetter,
    );
  }
}

class PropertyAccessorElementImpl extends MethodElementImpl implements PropertyAccessorElement {
  PropertyAccessorElementImpl({
    required super.name,
    required super.isAbstract,
    required super.isAsynchronous,
    required super.isExternal,
    required super.isGenerator,
    required super.isOperator,
    required super.isStatic,
    required super.isSynchronous,
    required super.enclosingElement,
    required this.isGetter,
    required this.isSetter,
  });

  @override
  final bool isGetter;

  @override
  final bool isSetter;
}

class ConstructorElementImpl extends ExecutableElementImpl implements ConstructorElement {
  ConstructorElementImpl({
    required super.name,
    required super.enclosingElement,
    required this.isConst,
    required this.isFactory,
    required super.isGenerator,
    this.superConstructor,
  }) : super(
         isAsynchronous: false,
         isExternal: false,
         isOperator: false,
         isStatic: false,
         isSynchronous: true,
         isAbstract: false,
       );

  @override
  final bool isConst;

  @override
  bool get isDefaultConstructor => name.isEmpty && parameters.every((e) => e.isOptional);

  @override
  final bool isFactory;

  @override
  ConstructorElementRef? get redirectedConstructor => _redirectedConstructor;

  @override
  final ConstructorElementRef? superConstructor;

  ConstructorElementRef? _redirectedConstructor;

  set redirectedConstructor(ConstructorElementRef? constructor) {
    _redirectedConstructor = constructor;
  }

  @override
  bool get isGenerative => !isFactory;
}

class ConstructorElementRef {
  final NamedTypeRef classType;
  final String name;

  ConstructorElementRef(this.classType, this.name);
}
