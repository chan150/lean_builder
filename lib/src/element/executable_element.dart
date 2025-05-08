part of 'element.dart';

/// {@template function_typed_element}
/// Base interface for elements that define a function type.
///
/// This includes functions, methods, constructors, and property accessors.
/// The interface provides access to parameters, return type, and the
/// overall function type that these elements define.
/// {@endtemplate}
abstract class FunctionTypedElement implements TypeParameterizedElement {
  /// {@template function_typed_element.parameters}
  /// The parameters defined by this executable element.
  /// {@endtemplate}
  List<ParameterElement> get parameters;

  /// {@template function_typed_element.return_type}
  /// The return type defined by this element.
  /// {@endtemplate}
  DartType get returnType;

  /// {@template function_typed_element.type}
  /// The type defined by this element.
  /// {@endtemplate}
  FunctionType get type;

  /// {@template function_typed_element.get_parameter}
  /// Retrieves a parameter by name from this executable's parameter list.
  ///
  /// @param name The name of the parameter to find
  /// @return The parameter with the specified name, or null if not found
  /// {@endtemplate}
  ParameterElement? getParameter(String name);
}

/// {@template executable_element}
/// Base interface for elements that can be executed as part of a program.
///
/// Executable elements include functions, methods, constructors, and property
/// accessors. They define a function type and have parameters and a return type.
/// They can also have various modifiers such as abstract, async, static, etc.
/// {@endtemplate}
abstract class ExecutableElement implements FunctionTypedElement {
  /// Whether the executable element is abstract.
  ///
  /// Executable elements are abstract if they are not external, and have no
  /// body.
  bool get isAbstract;

  /// {@template executable_element.is_asynchronous}
  /// Whether the executable element has body marked as being asynchronous.
  /// {@endtemplate}
  bool get isAsynchronous;

  /// Whether the executable element is external.
  ///
  /// Executable elements are external if they are explicitly marked as such
  /// using the 'external' keyword.
  bool get isExternal;

  /// {@template executable_element.is_generator}
  /// Whether the executable element has a body marked as being a generator.
  /// {@endtemplate}
  bool get isGenerator;

  /// {@template executable_element.is_operator}
  /// Whether the executable element is an operator.
  ///
  /// The test may be based on the name of the executable element, in which
  /// case the result will be correct when the name is legal.
  /// {@endtemplate}
  bool get isOperator;

  /// Whether the element is a static element.
  ///
  /// A static element is an element that is not associated with a particular
  /// instance, but rather with an entire library or class.
  bool get isStatic;

  /// {@template executable_element.is_synchronous}
  /// Whether the executable element has a body marked as being synchronous.
  /// {@endtemplate}
  bool get isSynchronous;

  /// {@template executable_element.has_implicit_return_type}
  /// Whether the executable element did not have an explicit return type
  /// specified for it in the original source.
  /// {@endtemplate}
  bool get hasImplicitReturnType;
}

/// {@template property_accessor_element}
/// Represents a getter or setter method for a property.
///
/// Property accessors provide a way to read and write a property's value
/// with custom logic. They can be defined explicitly with the `get` and `set`
/// keywords, or implicitly for fields.
/// {@endtemplate}
abstract class PropertyAccessorElement implements ExecutableElement {
  /// {@template property_accessor_element.is_getter}
  /// Whether this accessor is a getter.
  /// {@endtemplate}
  bool get isGetter;

  /// {@template property_accessor_element.is_setter}
  /// Whether this accessor is a setter.
  /// {@endtemplate}
  bool get isSetter;
}

/// {@template function_element}
/// Represents a function declaration in a Dart program.
///
/// Functions can be top-level, local (nested within another function),
/// or methods within a class. This element specifically represents
/// standalone functions, not methods.
/// {@endtemplate}
abstract class FunctionElement implements ExecutableElement {
  /// {@template function_element.main_function_name}
  /// The name of the function used as an entry point.
  /// {@endtemplate}
  static const String kMainFunctionName = "main";

  /// {@template function_element.call_method_name}
  /// The name of the special method that allows objects to be called as functions.
  /// {@endtemplate}
  static final String kCALLMethodName = "call";

  /// {@template function_element.is_entry_point}
  /// Whether the function is an entry point, i.e. a top-level function and
  /// has the name `main`.
  /// {@endtemplate}
  bool get isEntryPoint;
}

/// {@template constructor_element}
/// Represents a constructor declaration in a Dart class.
///
/// Constructors are special methods that create instances of a class.
/// They can be unnamed (default) or named, and can be generative or factory.
/// Constructors can also redirect to other constructors or invoke
/// superclass constructors.
/// {@endtemplate}
abstract class ConstructorElement
    implements ClassMemberElement, ExecutableElement {
  /// {@template constructor_element.is_const}
  /// Whether the constructor is a constant constructor.
  /// {@endtemplate}
  bool get isConst;

  /// {@template constructor_element.is_default_constructor}
  /// Whether the constructor can be used as a default constructor - unnamed,
  /// and has no required parameters.
  /// {@endtemplate}
  bool get isDefaultConstructor;

  /// {@template constructor_element.is_factory}
  /// Whether the constructor represents a factory constructor.
  /// {@endtemplate}
  bool get isFactory;

  /// {@template constructor_element.is_generative}
  /// Whether the constructor represents a generative constructor.
  /// {@endtemplate}
  bool get isGenerative;

  /// {@template constructor_element.redirected_constructor}
  /// The constructor to which this constructor is redirecting, or `null` if
  /// this constructor does not redirect to another constructor or if the
  /// library containing this constructor has not yet been resolved.
  /// {@endtemplate}
  ConstructorElementRef? get redirectedConstructor;

  /// {@template constructor_element.super_constructor}
  /// The constructor of the superclass that this constructor invokes, or
  /// `null` if this constructor redirects to another constructor, or if the
  /// library containing this constructor has not yet been resolved.
  /// {@endtemplate}
  ConstructorElementRef? get superConstructor;
}

/// {@template method_element}
/// Represents a method declaration in a class, mixin, or extension.
///
/// Methods are functions that are associated with objects and have access
/// to their properties and other methods.
/// {@endtemplate}
abstract class MethodElement implements ClassMemberElement, ExecutableElement {
  @override
  Element get enclosingElement;
}

/// {@template executable_element_impl}
/// Implementation of an executable element.
///
/// This class provides common functionality for all types of executable
/// elements, including parameters management, return type and function type
/// handling, and various modifier flags.
/// {@endtemplate}
abstract class ExecutableElementImpl extends ElementImpl
    with TypeParameterizedElementMixin
    implements ExecutableElement {
  /// {@template executable_element_impl.constructor}
  /// Creates an executable element with the specified properties.
  ///
  /// @param name The name of the executable element
  /// @param isAbstract Whether the element is abstract
  /// @param isAsynchronous Whether the element is asynchronous
  /// @param isExternal Whether the element is external
  /// @param isGenerator Whether the element is a generator
  /// @param isOperator Whether the element is an operator
  /// @param isStatic Whether the element is static
  /// @param isSynchronous Whether the element is synchronous
  /// @param enclosingElement The element containing this executable
  /// {@endtemplate}
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
    for (final ParameterElement parameter in _parameters) {
      if (parameter.name == name) {
        return parameter;
      }
    }
    return null;
  }

  /// {@template executable_element_impl.set_return_type}
  /// Sets the return type of this executable element.
  ///
  /// @param type The return type to set
  /// {@endtemplate}
  set returnType(DartType type) {
    _returnType = type;
  }

  @override
  FunctionType get type => _type!;

  final List<ParameterElement> _parameters = <ParameterElement>[];
  FunctionType? _type;

  /// {@template executable_element_impl.add_parameter}
  /// Adds a parameter to this executable element's parameter list.
  ///
  /// @param parameter The parameter to add
  /// {@endtemplate}
  void addParameter(ParameterElement parameter) {
    _parameters.add(parameter);
  }

  /// {@template executable_element_impl.set_type}
  /// Sets the function type of this executable element.
  ///
  /// @param type The function type to set
  /// {@endtemplate}
  set type(FunctionType type) {
    _type = type;
  }

  @override
  DartType instantiate(NamedDartType typeRef) {
    Substitution substitution = Substitution.fromPairs(
      typeParameters,
      typeRef.typeArguments,
    );
    return substitution.substituteType(type, isNullable: typeRef.isNullable);
  }
}

/// {@template function_element_impl}
/// Implementation of a function element in a Dart program.
///
/// This class represents standalone functions (not methods) and provides
/// concrete implementations of the functions-specific functionality.
/// {@endtemplate}
class FunctionElementImpl extends ExecutableElementImpl
    implements FunctionElement {
  /// {@template function_element_impl.constructor}
  /// Creates a function element with the specified properties.
  ///
  /// @param name The name of the function
  /// @param isAbstract Whether the function is abstract
  /// @param isAsynchronous Whether the function is asynchronous
  /// @param isExternal Whether the function is external
  /// @param isGenerator Whether the function is a generator
  /// @param isOperator Whether the function is an operator
  /// @param isStatic Whether the function is static
  /// @param isSynchronous Whether the function is synchronous
  /// @param enclosingElement The element containing this function
  /// {@endtemplate}
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

/// {@template method_element_impl}
/// Implementation of a method element in a Dart class.
///
/// This class represents methods defined within classes, mixins, or extensions
/// and provides concrete implementations of method-specific functionality.
/// {@endtemplate}
class MethodElementImpl extends ExecutableElementImpl implements MethodElement {
  /// {@template method_element_impl.constructor}
  /// Creates a method element with the specified properties.
  ///
  /// @param name The name of the method
  /// @param isAbstract Whether the method is abstract
  /// @param isAsynchronous Whether the method is asynchronous
  /// @param isExternal Whether the method is external
  /// @param isGenerator Whether the method is a generator
  /// @param isOperator Whether the method is an operator
  /// @param isStatic Whether the method is static
  /// @param isSynchronous Whether the method is synchronous
  /// @param enclosingElement The element containing this method
  /// {@endtemplate}
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

  /// {@template method_element_impl.to_property_accessor_element}
  /// Converts this method element to a property accessor element.
  ///
  /// This is used when a method needs to be treated as a getter or setter,
  /// typically for code generation purposes or to adapt a method's interface.
  ///
  /// @param isGetter Whether the accessor is a getter
  /// @param isSetter Whether the accessor is a setter
  /// @return A property accessor element based on this method
  /// {@endtemplate}
  PropertyAccessorElementImpl toPropertyAccessorElement({
    required bool isGetter,
    required bool isSetter,
  }) {
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

/// {@template property_accessor_element_impl}
/// Implementation of a property accessor element in a Dart class.
///
/// This class represents getter and setter methods that provide access
/// to properties. They can be explicitly defined with the `get` and `set`
/// keywords or implicitly created for fields.
/// {@endtemplate}
class PropertyAccessorElementImpl extends MethodElementImpl
    implements PropertyAccessorElement {
  /// {@template property_accessor_element_impl.constructor}
  /// Creates a property accessor element with the specified properties.
  ///
  /// @param name The name of the accessor
  /// @param isAbstract Whether the accessor is abstract
  /// @param isAsynchronous Whether the accessor is asynchronous
  /// @param isExternal Whether the accessor is external
  /// @param isGenerator Whether the accessor is a generator
  /// @param isOperator Whether the accessor is an operator
  /// @param isStatic Whether the accessor is static
  /// @param isSynchronous Whether the accessor is synchronous
  /// @param enclosingElement The element containing this accessor
  /// @param isGetter Whether this is a getter accessor
  /// @param isSetter Whether this is a setter accessor
  /// {@endtemplate}
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

/// {@template constructor_element_impl}
/// Implementation of a constructor element in a Dart class.
///
/// This class represents constructors that create instances of classes.
/// It provides implementations for constructor-specific functionality
/// such as handling redirecting constructors, superclass constructor calls,
/// and different constructor types (const, factory, etc.).
/// {@endtemplate}
class ConstructorElementImpl extends ExecutableElementImpl
    implements ConstructorElement {
  /// {@template constructor_element_impl.constructor}
  /// Creates a constructor element with the specified properties.
  ///
  /// @param name The name of the constructor (empty for default constructor)
  /// @param enclosingElement The class containing this constructor
  /// @param isConst Whether the constructor is a constant constructor
  /// @param isFactory Whether the constructor is a factory constructor
  /// @param isGenerator Whether the constructor is a generator
  /// @param superConstructor Reference to the superclass constructor called, if any
  /// {@endtemplate}
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
  bool get isDefaultConstructor =>
      name.isEmpty && parameters.every((ParameterElement e) => e.isOptional);

  @override
  final bool isFactory;

  @override
  ConstructorElementRef? get redirectedConstructor => _redirectedConstructor;

  @override
  final ConstructorElementRef? superConstructor;

  ConstructorElementRef? _redirectedConstructor;

  /// {@template constructor_element_impl.set_redirected_constructor}
  /// Sets the constructor to which this constructor redirects.
  ///
  /// @param constructor Reference to the redirected constructor
  /// {@endtemplate}
  set redirectedConstructor(ConstructorElementRef? constructor) {
    _redirectedConstructor = constructor;
  }

  @override
  bool get isGenerative => !isFactory;

  @override
  String toString() {
    final StringBuffer buffer = StringBuffer();
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

/// {@template constructor_element_ref}
/// A reference to a constructor in a class.
///
/// This class is used to represent references to constructors from other
/// constructors, such as in redirecting constructors or super constructor calls.
/// It contains the class type and constructor name information needed to
/// identify the target constructor.
/// {@endtemplate}
class ConstructorElementRef {
  /// {@template constructor_element_ref.class_type}
  /// The type of the class containing the referenced constructor.
  /// {@endtemplate}
  final NamedDartType classType;

  /// {@template constructor_element_ref.name}
  /// The name of the referenced constructor.
  ///
  /// This is an empty string for the default (unnamed) constructor.
  /// {@endtemplate}
  final String name;

  /// {@template constructor_element_ref.constructor}
  /// Creates a reference to a constructor in a class.
  ///
  /// @param classType The type of the class containing the constructor
  /// @param name The name of the constructor (empty for default constructor)
  /// {@endtemplate}
  ConstructorElementRef(this.classType, this.name);
}
