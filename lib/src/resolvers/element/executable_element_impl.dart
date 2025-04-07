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

  DartType? _returnType;

  @override
  DartType get returnType => _returnType!;

  @override
  ParameterElement? getParameter(String name) {
    for (final parameter in _parameters) {
      if (parameter.name == name) {
        return parameter;
      }
    }
    return null;
  }

  set returnType(DartType type) {
    _returnType = type;
  }

  @override
  FunctionType get type => _type!;

  final List<ParameterElement> _parameters = [];
  FunctionType? _type;

  void addParameter(ParameterElement parameter) {
    _parameters.add(parameter);
  }

  set type(FunctionType type) {
    _type = type;
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
  ConstructorElement? get redirectedConstructor => _redirectedConstructor;

  @override
  final ConstructorElement? superConstructor;

  ConstructorElement? _redirectedConstructor;

  set redirectedConstructor(ConstructorElement? constructor) {
    _redirectedConstructor = constructor;
  }
}
