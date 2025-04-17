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

abstract class MethodElement implements ClassMemberElement, ExecutableElement {}
