import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:code_genie/src/resolvers/const/constant.dart';
import 'package:code_genie/src/resolvers/element_resolver.dart';
import 'package:code_genie/src/resolvers/file_asset.dart';
import 'package:code_genie/src/resolvers/type/substitution.dart';
import 'package:code_genie/src/resolvers/type/type_ref.dart';
import 'package:code_genie/src/scanner/identifier_ref.dart';
import 'package:code_genie/src/scanner/scan_results.dart';
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

  String get srcId => src.id;

  IdentifierLocation identifierLocationOf(String identifier, TopLevelIdentifierType type);

  List<Element> get resolvedElements;

  Iterable<ClassElementImpl> get classes;

  Iterable<MixinElementImpl> get mixins;

  Iterable<EnumElementImpl> get enums;

  Iterable<FunctionElement> get functions;

  Iterable<TypeAliasElement> get typeAliases;

  ClassElementImpl? getClass(String name);

  InterfaceElement? getInterfaceElement(String name);

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
}

abstract class EnumElement implements InterfaceElement {}

abstract class MixinElement implements Element {
  List<TypeRef> get superclassConstraints;
}

abstract class NullElement extends Element {}
