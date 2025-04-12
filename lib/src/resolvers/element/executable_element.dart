part of 'element.dart';

abstract class FunctionTypedElement implements TypeParameterizedElement {
  /// The parameters defined by this executable element.
  List<ParameterElement> get parameters;

  /// The return type defined by this element.
  TypeRef get returnType;

  /// The type defined by this element.
  FunctionTypeRef get type;

  ParameterElement? getParameter(String name);
}

abstract class ExecutableElement implements FunctionTypedElement {
  bool get hasImplicitReturnType;

  bool get isAbstract;

  bool get isAsynchronous;

  bool get isExternal;

  bool get isGenerator;

  bool get isOperator;

  bool get isStatic;

  bool get isSynchronous;
}

abstract class PropertyAccessorElement implements ExecutableElement {
  PropertyAccessorElement? get correspondingGetter;

  PropertyAccessorElement? get correspondingSetter;

  bool get isGetter;

  bool get isSetter;

  // /// The field or top-level variable associated with this accessor.
  // ///
  // /// If this accessor was explicitly defined (is not synthetic) then the
  // /// variable associated with it will be synthetic.
  // PropertyInducingElement get variable;
}

abstract class FunctionElement implements ExecutableElement {
  /// The name of the method that can be implemented by a class to allow its
  /// instances to be invoked as if they were a function.
  static final String kCallMethodName = "call";

  /// The name of the synthetic function defined for libraries that are
  /// deferred.
  static final String kLoadLibraryName = "loadLibrary";

  /// The name of the function used as an entry point.
  static const String kMainFunctionName = "main";

  /// The name of the method that will be invoked if an attempt is made to
  /// invoke an undefined method on an object.
  static final String kNoSuchMethodName = "noSuchMethod";

  /// Whether the function is an entry point, i.e. a top-level function and
  /// has the name `main`.
  bool get isEntryPoint;
}

abstract class ConstructorElement implements ClassMemberElement, ExecutableElement {
  /// Whether the constructor is a const constructor.
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

abstract class MethodElement implements ClassMemberElement, ExecutableElement {}
