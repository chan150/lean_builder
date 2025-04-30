import 'package:analyzer/dart/ast/ast.dart';
import 'package:lean_builder/src/asset/asset.dart';
import 'package:lean_builder/src/graph/identifier_ref.dart';
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

abstract class Element {
  String get name;

  @override
  String toString() => name;

  Element? get enclosingElement;

  LibraryElement get library;

  String get identifier;

  List<ElementAnnotation> get metadata;

  ElementAnnotation? getAnnotation(String name);

  Asset get librarySrc;

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

  bool get isPrivate;

  bool get isPublic;
}

abstract class TypeParameterizedElement extends Element {
  List<TypeParameterType> get typeParameters;

  DartType instantiate(NamedDartType typeRef);
}

abstract class TypeAliasElement implements TypeParameterizedElement {
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

abstract class InstantiatableElement extends Element {
  DartType instantiate(NamedDartType typeRef);
}

abstract class InstanceElement extends Element implements TypeParameterizedElement {
  List<PropertyAccessorElement> get accessors;

  List<FieldElement> get fields;

  List<MethodElement> get methods;

  InterfaceType get thisType;
}

abstract class InterfaceElement extends InstanceElement with TypeParameterizedElementMixin {
  NamedDartType? get superType;

  List<InterfaceType> get allSuperTypes;

  List<NamedDartType> get mixins;

  List<NamedDartType> get interfaces;

  List<ConstructorElement> get constructors;

  ConstructorElement? get unnamedConstructor;

  ConstructorElement? getConstructor(String name);

  MethodElement? getMethod(String name);

  FieldElement? getField(String name);

  bool hasMethod(String name);

  bool hasPropertyAccessor(String name);

  bool hasField(String name);

  bool hasConstructor(String name);
}

abstract class LibraryElement extends Element {
  Asset get src;

  DeclarationRef buildDeclarationRef(String identifier, TopLevelIdentifierType type);

  CompilationUnit get compilationUnit;

  List<ClassElementImpl> get classes;

  Resolver get resolver;

  List<MixinElementImpl> get mixins;

  List<EnumElementImpl> get enums;

  List<FunctionElement> get functions;

  List<TypeAliasElement> get typeAliases;

  List<DirectiveElement> get directives;

  ClassElementImpl? getClass(String name);

  Element? getElement(String name);

  MixinElementImpl? getMixin(String name);

  EnumElementImpl? getEnum(String name);

  FunctionElement? getFunction(String name);

  TypeAliasElement? getTypeAlias(String name);

  /// All of the resolved declarations in this library annotated with [checker].
  Iterable<AnnotatedElement> annotatedWith(TypeChecker checker);

  /// All of the resolved declarations in this library annotated with exactly [checker].
  Iterable<AnnotatedElement> annotatedWithExact(TypeChecker checker);
}

abstract class VariableElement extends Element {
  bool get hasImplicitType;

  bool get isConst;

  bool get isFinal;

  bool get isLate;

  bool get isStatic;

  bool get hasInitializer;

  @override
  String get name;

  DartType get type;

  Constant? get constantValue;

  Expression? get initializer;
}

abstract class TopLevelVariableElement extends VariableElement {
  bool get isExternal;
}

abstract class ClassMemberElement extends Element {
  bool get isStatic;
}

abstract class FieldElement extends ClassMemberElement implements VariableElement {
  bool get isAbstract;

  bool get isCovariant;

  bool get isEnumConstant;

  bool get isExternal;

  PropertyAccessorElement? get getter;

  PropertyAccessorElement? get setter;
}

abstract class ParameterElement extends VariableElement {
  String? get defaultValueCode;

  bool get hasDefaultValue;

  bool get isCovariant;

  bool get isInitializingFormal;

  bool get isNamed;

  bool get isOptional;

  bool get isOptionalNamed;

  bool get isOptionalPositional;

  bool get isPositional;

  bool get isRequired;

  bool get isRequiredNamed;

  bool get isRequiredPositional;

  bool get isSuperFormal;

  @override
  String get name;

  List<ParameterElement> get parameters;

  List<TypeParameterType> get typeParameters;
}

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

abstract class EnumElement implements InterfaceElement {}

abstract class MixinElement implements Element {
  List<NamedDartType> get superclassConstraints;

  /// Whether the declaration has an explicit `base` modifier.
  bool get isBase;
}
