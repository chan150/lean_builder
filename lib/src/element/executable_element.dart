part of 'element.dart';

abstract class FunctionTypedElement implements TypeParameterizedElement {
  /// The parameters defined by this executable element.
  List<ParameterElement> get parameters;

  /// The return type defined by this element.
  DartType get returnType;

  /// The type defined by this element.
  FunctionType get type;

  ParameterElement? getParameter(String name);
}

abstract class ExecutableElement implements FunctionTypedElement {
  /// Whether the executable element is abstract.
  ///
  /// Executable elements are abstract if they are not external, and have no
  /// body.
  bool get isAbstract;

  /// Whether the executable element has body marked as being asynchronous.
  bool get isAsynchronous;

  /// Whether the executable element is external.
  ///
  /// Executable elements are external if they are explicitly marked as such
  /// using the 'external' keyword.
  bool get isExternal;

  /// Whether the executable element has a body marked as being a generator.
  bool get isGenerator;

  /// Whether the executable element is an operator.
  ///
  /// The test may be based on the name of the executable element, in which
  /// case the result will be correct when the name is legal.
  bool get isOperator;

  /// Whether the element is a static element.
  ///
  /// A static element is an element that is not associated with a particular
  /// instance, but rather with an entire library or class.
  bool get isStatic;

  /// Whether the executable element has a body marked as being synchronous.
  bool get isSynchronous;

  /// Whether the executable element did not have an explicit return type
  /// specified for it in the original source.
  bool get hasImplicitReturnType;
}

abstract class PropertyAccessorElement implements ExecutableElement {
  /// Whether this accessor is a getter.
  bool get isGetter;

  /// Whether this accessor is a setter.
  bool get isSetter;
}

abstract class FunctionElement implements ExecutableElement {
  /// The name of the function used as an entry point.
  static const String kMainFunctionName = "main";

  static final String kCALLMethodName = "call";

  /// Whether the function is an entry point, i.e. a top-level function and
  /// has the name `main`.
  bool get isEntryPoint;
}

abstract class ConstructorElement implements ClassMemberElement, ExecutableElement {
  /// Whether the constructor is a constant constructor.
  bool get isConst;

  /// Whether the constructor can be used as a default constructor - unnamed,
  /// and has no required parameters.
  bool get isDefaultConstructor;

  /// Whether the constructor represents a factory constructor.
  bool get isFactory;

  /// Whether the constructor represents a generative constructor.
  bool get isGenerative;

  /// The constructor to which this constructor is redirecting, or `null` if
  /// this constructor does not redirect to another constructor or if the
  /// library containing this constructor has not yet been resolved.
  ConstructorElementRef? get redirectedConstructor;

  /// The constructor of the superclass that this constructor invokes, or
  /// `null` if this constructor redirects to another constructor, or if the
  /// library containing this constructor has not yet been resolved.
  ConstructorElementRef? get superConstructor;
}

abstract class MethodElement implements ClassMemberElement, ExecutableElement {
  @override
  Element get enclosingElement;
}

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
  bool get hasImplicitReturnType => returnType == DartType.invalidType;

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

  @override
  DartType instantiate(NamedDartType typeRef) {
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

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.write('ConstructorElementImpl(');
    buffer.write('name: $name, ');
    buffer.write('isConst: $isConst, ');
    buffer.write('isFactory: $isFactory, ');
    buffer.write('isAbstract: $isAbstract, ');
    buffer.write('isAsynchronous: $isAsynchronous, ');
    buffer.write('isExternal: $isExternal, ');
    buffer.write('isGenerator: $isGenerator, ');
    buffer.write('isOperator: $isOperator, ');
    buffer.write('isStatic: $isStatic, ');
    buffer.write('isSynchronous: $isSynchronous, ');
    buffer.write('enclosingElement: ${enclosingElement.name}, ');
    if (redirectedConstructor != null) {
      buffer.write('redirectedConstructor: ${redirectedConstructor!.name}, ');
    }
    if (superConstructor != null) {
      buffer.write('superConstructor: ${superConstructor!.name}, ');
    }
    buffer.write(')');
    return buffer.toString();
  }
}

class ConstructorElementRef {
  final NamedDartType classType;
  final String name;

  ConstructorElementRef(this.classType, this.name);
}
