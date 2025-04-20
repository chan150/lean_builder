import 'package:analyzer/dart/ast/ast.dart';
import 'package:lean_builder/src/resolvers/constant/constant.dart';
import 'package:lean_builder/src/resolvers/element_resolver.dart';
import 'package:lean_builder/src/resolvers/file_asset.dart';
import 'package:lean_builder/src/resolvers/type/substitution.dart';
import 'package:lean_builder/src/resolvers/type/type_ref.dart';
import 'package:lean_builder/src/scanner/identifier_ref.dart';
import 'package:lean_builder/src/scanner/scan_results.dart';
import 'package:collection/collection.dart';

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

  AssetSrc get librarySrc;

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
}

abstract class TypeParameterizedElement extends Element {
  List<TypeParameterTypeRef> get typeParameters;

  TypeRef instantiate(NamedTypeRef typeRef);
}

abstract class TypeAliasElement implements TypeParameterizedElement {
  TypeRef get aliasedType;
}

abstract class InstantiatableElement extends Element {
  TypeRef instantiate(NamedTypeRef typeRef);
}

abstract class InstanceElement extends Element implements TypeParameterizedElement {
  List<PropertyAccessorElement> get accessors;

  List<FieldElement> get fields;

  List<MethodElement> get methods;

  NamedTypeRef get thisType;
}

abstract class InterfaceElement extends InstanceElement with TypeParameterizedElementMixin {
  TypeRef? get superType;

  List<TypeRef> get allSuperTypes;

  List<TypeRef> get mixins;

  List<TypeRef> get interfaces;

  List<ConstructorElement> get constructors;

  ConstructorElement? getConstructor(String name);

  ConstructorElement? get unnamedConstructor;

  MethodElement? getMethod(String name);

  FieldElement? getField(String name);

  bool hasMethod(String name);

  bool hasPropertyAccessor(String name);

  bool hasField(String name);

  bool hasConstructor(String name);
}

abstract class LibraryElement extends Element {
  AssetSrc get src;

  DeclarationRef buildDeclarationRef(String identifier, TopLevelIdentifierType type);

  CompilationUnit get compilationUnit;

  List<ClassElementImpl> get classes;

  ElementResolver get resolver;

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

  TypeRef get type;

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

  bool get isPrivate;

  bool get isPublic;
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

  List<TypeParameterTypeRef> get typeParameters;
}

abstract class ClassElement extends InterfaceElement {
  /// Whether the declaration has an explicit `abstract` modifier
  bool get isAbstract;

  /// Whether the declaration has an explicit `base` modifier.
  bool get isBase;

  /// Whether the class can be instantiated.
  bool get isConstructable;

  /// Whether the declaration has an explicit `final` modifier
  bool get isFinal;

  /// Whether the declaration has an explicit `interface` modifier
  bool get isInterface;

  /// Whether the class is a mixin application.
  ///
  /// A class is a mixin application if it was declared using the syntax
  /// `class A = B with C;`.
  bool get isMixinApplication;

  /// Whether the declaration has an explicit `mixin` modifier.
  bool get isMixinClass;

  /// Whether the declaration has an explicit `sealed` modifier.
  bool get isSealed;
}

abstract class EnumElement implements InterfaceElement {}

abstract class MixinElement implements Element {
  List<TypeRef> get superclassConstraints;

  /// Whether the declaration has an explicit `base` modifier.
  bool get isBase;
}
