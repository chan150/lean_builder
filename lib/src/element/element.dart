import 'package:analyzer/dart/ast/ast.dart';
import 'package:lean_builder/src/asset/asset.dart';
import 'package:lean_builder/src/graph/declaration_ref.dart';
import 'package:lean_builder/src/graph/scan_results.dart';
import 'package:lean_builder/src/resolvers/constant/constant.dart';
import 'package:lean_builder/src/resolvers/resolver.dart';
import 'package:collection/collection.dart';
import 'package:lean_builder/src/type/substitution.dart';
import 'package:lean_builder/src/type/type.dart';
import 'package:lean_builder/src/type/type_checker.dart';

part 'element_annotation.dart';

part 'executable_element.dart';

part 'element_impl.dart';

part 'directive_element.dart';

/// {@template element}
/// The base class for all elements in the Dart language.
///
/// Elements represent the building blocks of a Dart program, such as classes,
/// methods, fields, and variables. They provide a way to access information
/// about the structure and semantics of the code.
///
/// This class provides a common interface for accessing properties like the
/// element's name, enclosing element, library, and metadata. It also defines
/// methods for checking the presence of specific annotations.
/// {@endtemplate}
abstract class Element {
  /// The name of the element.
  String get name;

  @override
  String toString() => name;

  /// The enclosing element of this element.
  ///
  /// This is the element that contains this element, such as a class or a library.
  Element? get enclosingElement;

  /// The library that contains this element.
  LibraryElement get library;

  /// A String that uniquely identifies this element
  ///
  /// This is typically the name of the element + the source id of the library
  String get identifier;

  /// The metadata associated with this element.
  List<ElementAnnotation> get metadata;

  /// Returns the first annotation with the given name, or null if no such
  ElementAnnotation? getAnnotation(String name);

  /// The source code location of this element.
  Asset get librarySrc;

  /// The documentation comment associated with this element if it has one.
  ///
  /// This is the text of the comment, including any leading `///` or `/**`
  String? get documentationComment;

  /// Whether the element has an annotation of the form `@alwaysThrows`.
  bool get hasAlwaysThrows;

  /// Whether the element has an annotation of the form `@deprecated`
  /// or `@Deprecated('..')`.
  bool get hasDeprecated;

  /// Whether the element has an annotation of the form `@doNotStore`.
  bool get hasDoNotStore;

  /// Whether the element has an annotation of the form `@factory`.
  bool get hasFactory;

  /// Whether the element has an annotation of the form `@internal`.
  bool get hasInternal;

  /// Whether the element has an annotation of the form `@isTest`.
  bool get hasIsTest;

  /// Whether the element has an annotation of the form `@isTestGroup`.
  bool get hasIsTestGroup;

  /// Whether the element has an annotation of the form `@literal`.
  bool get hasLiteral;

  /// Whether the element has an annotation of the form `@mustBeOverridden`.
  bool get hasMustBeOverridden;

  /// Whether the element has an annotation of the form `@mustCallSuper`.
  bool get hasMustCallSuper;

  /// Whether the element has an annotation of the form `@nonVirtual`.
  bool get hasNonVirtual;

  /// Whether the element has an annotation of the form `@optionalTypeArgs`.
  bool get hasOptionalTypeArgs;

  /// Whether the element has an annotation of the form `@override`.
  bool get hasOverride;

  /// Whether the element has an annotation of the form `@protected`.
  bool get hasProtected;

  /// Whether the element has an annotation of the form `@redeclare`.
  bool get hasRedeclare;

  /// Whether the element has an annotation of the form `@reopen`.
  bool get hasReopen;

  /// Whether the element has an annotation of the form `@required`.
  bool get hasRequired;

  /// Whether the element has an annotation of the form `@sealed`.
  bool get hasSealed;

  /// Whether the element has an annotation of the form `@useResult`
  /// or `@UseResult('..')`.
  bool get hasUseResult;

  /// Whether the element has an annotation of the form `@visibleForOverriding`.
  bool get hasVisibleForOverriding;

  /// Whether the name of this element starts with an underscore.
  bool get isPrivate;

  /// Whether the name of this element does not start with an underscore.
  ///
  /// This is the opposite of [isPrivate].
  bool get isPublic;

  /// The length of the name of this element in the file that contains the
  /// declaration of this element, or `0` if this element does not have a name.
  int get nameLength;

  /// The offset of the name of this element in the file that contains the
  /// declaration of this element, or `-1` if this element is synthetic, does
  /// not have a name, or otherwise does not have an offset.
  int get nameOffset;

  /// The offset of the code of this element in the file that contains the
  int get codeOffset;

  /// The length of the code of this element in the file that contains the
  int get codeLength;

  /// The source code of this element.
  String? get source;
}

/// {@template type_parameterized_element}
/// Represents an element that can have type parameters.
///
/// This includes classes, mixins, type aliases, and functions.
/// {@endtemplate}
abstract class TypeParameterizedElement extends Element {
  /// The type parameters of this element.
  ///
  /// if this element does not have any type parameters, this will be an empty list.
  List<TypeParameterType> get typeParameters;

  /// instantiates the type parameters of this element with the given type
  DartType instantiate(NamedDartType typeRef);
}

/// {@template type_alias_element}
/// Represents a typedef declaration in the Dart language.
/// {@endtemplate}
abstract class TypeAliasElement implements TypeParameterizedElement {
  /// The type this typedef refers to.
  DartType get aliasedType;

  /// gets the target interface of the type alias if this is an interface type alias or points to
  /// another interface type alias.
  ///
  /// e.g typedef A = RealInterfaceType
  /// typedef B = A
  ///
  /// In this case, aliasedInterfaceType will be RealInterfaceType
  InterfaceType? get aliasedInterfaceType;
}

/// {@template instance_element}
/// Represents an element that is an instance of a class.
/// {@endtemplate}
abstract class InstanceElement extends Element
    implements TypeParameterizedElement {
  /// The accessors of this element.
  List<PropertyAccessorElement> get accessors;

  /// The fields of this element.
  List<FieldElement> get fields;

  /// The methods of this element.
  List<MethodElement> get methods;

  /// The type of `this` in this element.
  InterfaceType get thisType;
}

/// {@template interface_element}
/// Represents an element that is an interface.
///
/// This includes classes, enums, and mixins.
/// {@endtemplate}
abstract class InterfaceElement extends InstanceElement
    with TypeParameterizedElementMixin {
  /// The supertype of this element, or `null` if this element does not have a supertype.
  NamedDartType? get superType;

  /// A list containing all of the supertypes of this interface.
  List<InterfaceType> get allSupertypes;

  /// The mixins of this element.
  List<NamedDartType> get mixins;

  /// The interfaces of this element.
  List<NamedDartType> get interfaces;

  /// The constructors of this element.
  List<ConstructorElement> get constructors;

  /// The unnamed constructor of this element, or `null` if this element does not have an unnamed constructor.
  ConstructorElement? get unnamedConstructor;

  /// Returns the constructor with the given name, or `null` if this element does not have a constructor with the given name.
  ConstructorElement? getConstructor(String name);

  /// Returns the method with the given name, or `null` if this element does not have a method with the given name.
  MethodElement? getMethod(String name);

  /// Returns the field with the given name, or `null` if this element does not have a field with the given name.
  FieldElement? getField(String name);

  /// Returns `true` if this element has a method with the given name.
  bool hasMethod(String name);

  /// Returns `true` if this element has a property accessor with the given name.
  bool hasPropertyAccessor(String name);

  /// Returns `true` if this element has a field with the given name.
  bool hasField(String name);

  /// Returns `true` if this element has a constructor with the given name.
  bool hasConstructor(String name);
}

/// {@template library_element}
/// Represents a library element in the Dart language.
/// {@endtemplate}
abstract class LibraryElement extends Element {
  /// The source code of this library.
  Asset get src;

  /// Builds a declaration reference for the given identifier and type.
  DeclarationRef buildDeclarationRef(String identifier, ReferenceType type);

  /// The compilation unit of this library.
  CompilationUnit get compilationUnit;

  /// The classes in this library.
  List<ClassElementImpl> get classes;

  /// The resolver for this library.
  ResolverImpl get resolver;

  /// The mixins in this library.
  List<MixinElementImpl> get mixins;

  /// The enums in this library.
  List<EnumElementImpl> get enums;

  /// The functions in this library.
  List<FunctionElement> get functions;

  /// The type aliases in this library.
  List<TypeAliasElement> get typeAliases;

  /// The directives in this library.
  List<DirectiveElement> get directives;

  /// Returns the class with the given name, or `null` if this library does not have a class with the given name.
  ClassElementImpl? getClass(String name);

  /// Returns the element with the given name, or `null` if this library does not have an element with the given name.
  Element? getElement(String name);

  /// Returns the mixin with the given name, or `null` if this library does not have a mixin with the given name.
  MixinElementImpl? getMixin(String name);

  /// Returns the enum with the given name, or `null` if this library does not have an enum with the given name.
  EnumElementImpl? getEnum(String name);

  /// Returns the function with the given name, or `null` if this library does not have a function with the given name.
  FunctionElement? getFunction(String name);

  /// Returns the type alias with the given name, or `null` if this library does not have a type alias with the given name.
  TypeAliasElement? getTypeAlias(String name);

  /// All of the resolved declarations in this library annotated with [checker].
  Iterable<AnnotatedElement> annotatedWith(TypeChecker checker);

  /// All of the resolved declarations in this library annotated with exactly [checker].
  Iterable<AnnotatedElement> annotatedWithExact(TypeChecker checker);
}

/// {@template variable_element}
/// Represents a variable element in the Dart language.
/// {@endtemplate}
abstract class VariableElement extends Element {
  /// Whether the variable has an implicit type.
  bool get hasImplicitType;

  /// Whether the variable is a constant.
  bool get isConst;

  /// Whether the variable is final.
  bool get isFinal;

  /// Whether the variable is late.
  bool get isLate;

  /// Whether the variable is static.
  bool get isStatic;

  /// Whether the variable has an initializer.
  bool get hasInitializer;

  @override
  String get name;

  /// The type of the variable.
  DartType get type;

  /// The constant value of the variable, or `null` if the variable does not have a constant value.
  Constant? get constantValue;

  /// The initializer of the variable, or `null` if the variable does not have an initializer.
  Expression? get initializer;
}

/// {@template top_level_variable_element}
/// Represents a top-level variable element in the Dart language.
/// {@endtemplate}
abstract class TopLevelVariableElement extends VariableElement {
  /// Whether the variable is external.
  bool get isExternal;
}

/// {@template class_member_element}
/// Represents a class member element in the Dart language.
/// {@endtemplate}
abstract class ClassMemberElement extends Element {
  /// Whether the member is static.
  bool get isStatic;
}

/// {@template field_element}
/// Represents a field element in the Dart language.
/// {@endtemplate}
abstract class FieldElement extends ClassMemberElement
    implements VariableElement {
  /// Whether the field is abstract.
  bool get isAbstract;

  /// Whether the field is covariant.
  bool get isCovariant;

  /// Whether the field is an enum constant.
  bool get isEnumConstant;

  /// Whether the field is external.
  bool get isExternal;

  /// Whether the field is synthetic.
  bool get isSynthetic;

  /// The getter for this field, or `null` if this field does not have a getter.
  PropertyAccessorElement? get getter;

  /// The setter for this field, or `null` if this field does not have a setter.
  PropertyAccessorElement? get setter;

  @override
  Element get enclosingElement;
}

/// {@template parameter_element}
/// Represents a parameter element in the Dart language.
/// {@endtemplate}
abstract class ParameterElement extends VariableElement {
  /// The default value code for this parameter, or `null` if this parameter does not have a default value.
  String? get defaultValueCode;

  /// Whether this parameter has a default value.
  bool get hasDefaultValue;

  /// Whether this parameter is covariant.
  bool get isCovariant;

  /// Whether this parameter is an initializing formal.
  bool get isInitializingFormal;

  /// Whether this parameter is named.
  bool get isNamed;

  /// Whether this parameter is optional.
  bool get isOptional;

  /// Whether this parameter is optional and named.
  bool get isOptionalNamed;

  /// Whether this parameter is optional and positional.
  bool get isOptionalPositional;

  /// Whether this parameter is positional.
  bool get isPositional;

  /// Whether this parameter is required.
  bool get isRequired;

  /// Whether this parameter is required and named.
  bool get isRequiredNamed;

  /// Whether this parameter is required and positional.
  bool get isRequiredPositional;

  /// Whether this parameter is a super formal.
  bool get isSuperFormal;

  @override
  String get name;

  /// The parameters of this parameter.
  List<ParameterElement> get parameters;

  /// The type parameters of this parameter.
  List<TypeParameterType> get typeParameters;
}

/// {@template class_element}
/// Represents a class element in the Dart language.
/// {@endtemplate}
abstract class ClassElement extends InterfaceElement {
  /// Whether the declaration has an explicit `abstract` modifier
  bool get hasAbstract;

  /// Whether the declaration has an explicit `base` modifier.
  bool get hasBase;

  /// Whether the class can be instantiated.
  bool get isConstructable;

  /// Whether the declaration has an explicit `final` modifier
  bool get hasFinal;

  /// Whether the declaration has an explicit `interface` modifier
  bool get hasInterface;

  /// Whether the class is a mixin application.
  ///
  /// A class is a mixin application if it was declared using the syntax
  /// `class A = B with C;`.
  bool get isMixinApplication;

  /// Whether the declaration has an explicit `mixin` modifier.
  bool get isMixinClass;

  /// Whether the declaration has an explicit `sealed` modifier.
  bool get hasSealedKeyword;
}

/// {@template enum_element}
/// Represents an enum element in the Dart language.
/// {@endtemplate}
abstract class EnumElement implements InterfaceElement {}

/// {@template mixin_element}
/// Represents a mixin element in the Dart language.
/// {@endtemplate}
abstract class MixinElement implements Element {
  /// The mixin constraints of the mixin.
  ///
  /// this represents the on clause of the mixin declaration.
  List<NamedDartType> get superclassConstraints;

  /// Whether the declaration has an explicit `base` modifier.
  bool get isBase;
}
