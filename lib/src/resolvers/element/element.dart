import 'package:analyzer/dart/ast/ast.dart';
import 'package:lean_builder/src/resolvers/const/constant.dart';
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

part 'executable_element_impl.dart';

part 'directive_element.dart';

abstract class Element {
  String get name;

  @override
  String toString() => name;

  Element? get enclosingElement;

  LibraryElement get library;

  String get identifier;

  List<ElementAnnotation> get metadata;
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

  TypeRef get thisType;
}

abstract class InterfaceElement extends InstanceElement with TypeParameterizedElementMixin {
  TypeRef? get superType;

  List<TypeRef> get allSuperTypes;

  List<TypeRef> get mixins;

  List<TypeRef> get interfaces;

  MethodElement? getMethod(String name) => methods.firstWhereOrNull((e) => e.name == name);

  FieldElement? getField(String name) => fields.firstWhereOrNull((e) => e.name == name);
}

abstract class LibraryElement extends Element {
  AssetSrc get src;

  DeclarationRef buildLocation(String identifier, TopLevelIdentifierType type);

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
  List<ConstructorElement> get constructors;

  ConstructorElement? getConstructor(String name);

  ConstructorElement? get unnamedConstructor;

  /// Whether the class is abstract. A class is abstract if it has an
  /// explicit `abstract` modifier. Note, that this definition of
  /// <i>abstract</i> is different from <i>has unimplemented members</i>.
  bool get isAbstract;

  /// Whether this class is a base class.
  ///
  /// A class is a base class if it has an explicit `base` modifier, or the
  /// class has a `base` induced modifier and [isSealed] is `true` as well.
  /// The base modifier allows the class to be extended but not implemented.
  bool get isBase;

  /// Whether the class can be instantiated.
  bool get isConstructable;

  /// Whether the class is a final class.
  ///
  /// A class is a final class if it has an explicit `final` modifier, or the
  /// class has a `final` induced modifier and [isSealed] is `true` as well.
  /// The final modifier prohibits this class from being extended, implemented,
  /// or mixed in.
  bool get isFinal;

  /// Whether the class is an interface class.
  ///
  /// A class is an interface class if it has an explicit `interface` modifier,
  /// or the class has an `interface` induced modifier and [isSealed] is `true`
  /// as well. The interface modifier allows the class to be implemented, but
  /// not extended or mixed in.
  bool get isInterface;

  /// Whether the class is a mixin application.
  ///
  /// A class is a mixin application if it was declared using the syntax
  /// `class A = B with C;`.
  bool get isMixinApplication;

  /// Whether the class is a mixin class.
  ///
  /// A class is a mixin class if it has an explicit `mixin` modifier.
  bool get isMixinClass;

  /// Whether the class is a sealed class.
  ///
  /// A class is a sealed class if it has an explicit `sealed` modifier.
  bool get isSealed;
}

abstract class EnumElement implements InterfaceElement {}

abstract class MixinElement implements Element {
  List<TypeRef> get superclassConstraints;

  /// Whether the mixin is a base mixin.
  ///
  /// A mixin is a base mixin if it has an explicit `base` modifier.
  /// The base modifier allows a mixin to be mixed in, but not implemented.
  bool get isBase;
}
