part of 'element.dart';

abstract class ExecutableElementImpl extends ElementImpl
    with TypeParameterizedElementMixin
    implements ExecutableElement {
  ExecutableElementImpl({
    required this.name,
    this.isAbstract = false,
    this.isAsynchronous = false,
    this.isExternal = false,
    this.isGenerator = false,
    this.isOperator = false,
    this.isStatic = false,
    this.isSynchronous = true,
    this.hasImplicitReturnType = false,
    required this.enclosingElement,
  });

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
  final bool hasImplicitReturnType;

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
    super.isAbstract,
    super.isAsynchronous,
    super.isExternal,
    super.isGenerator,
    super.isOperator,
    super.isStatic,
    super.isSynchronous,
    required super.enclosingElement,
  });

  @override
  bool get isEntryPoint => name == FunctionElement.kMainFunctionName;
}

class MethodElementImpl extends ExecutableElementImpl implements MethodElement {
  MethodElementImpl({
    required super.name,
    super.isAbstract,
    super.isAsynchronous,
    super.isExternal,
    super.isGenerator,
    super.isOperator,
    super.isStatic,
    super.isSynchronous,
    required super.enclosingElement,
  });
}

class ConstructorElementImpl extends ExecutableElementImpl implements ConstructorElement {
  ConstructorElementImpl({
    required super.name,
    required super.enclosingElement,
    required this.isConst,
    required this.isDefaultConstructor,
    required this.isFactory,
    required this.isGenerative,
    this.superConstructor,
  }) : super(isAsynchronous: false);

  @override
  final bool isConst;

  @override
  final bool isDefaultConstructor;

  @override
  final bool isFactory;

  @override
  final bool isGenerative;

  @override
  ConstructorElementRef? get redirectedConstructor => _redirectedConstructor;

  @override
  final ConstructorElementRef? superConstructor;

  ConstructorElementRef? _redirectedConstructor;

  set redirectedConstructor(ConstructorElementRef? constructor) {
    _redirectedConstructor = constructor;
  }
}

class ConstructorElementRef {
  final NamedTypeRef classType;
  final String name;

  ConstructorElementRef(this.classType, this.name);
}
