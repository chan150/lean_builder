part of 'element.dart';

abstract class ExecutableElementImpl extends ElementImpl implements ExecutableElement {
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
    required this.library,
    this.enclosingElement,
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
  final Element? enclosingElement;

  @override
  final bool hasImplicitReturnType;

  @override
  final LibraryElement library;

  @override
  List<ParameterElement> get parameters => _parameters;

  DartType? _returnType;

  @override
  DartType get returnType => _returnType!;

  void setReturnType(DartType type) {
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

class FunctionElementImpl extends ExecutableElementImpl with TypeParameterizedElementMixin implements FunctionElement {
  FunctionElementImpl({
    required super.name,
    required super.library,
    super.isAbstract,
    super.isAsynchronous,
    super.isExternal,
    super.isGenerator,
    super.isOperator,
    super.isStatic,
    super.isSynchronous,
    super.enclosingElement,
  });

  @override
  bool get isEntryPoint => name == FunctionElement.kMainFunctionName;
}

class MethodElementImpl extends ExecutableElementImpl with TypeParameterizedElementMixin implements MethodElement {
  MethodElementImpl({
    required super.name,
    super.isAbstract,
    super.isAsynchronous,
    super.isExternal,
    super.isGenerator,
    super.isOperator,
    super.isStatic,
    super.isSynchronous,
    required Element enclosingElement,
  }) : super(library: enclosingElement.library, enclosingElement: enclosingElement);
}
