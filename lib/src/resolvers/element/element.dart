import 'package:analyzer/dart/element/element.dart';
import 'package:code_genie/src/resolvers/const/constant.dart';
import 'package:code_genie/src/resolvers/file_asset.dart';
import 'package:code_genie/src/resolvers/type/type.dart';
import 'package:collection/collection.dart';

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

  static final nullElement = NullElementImpl();
}

abstract class TypeParameterElement implements Element {
  DartType? get bound;
}

abstract class TypeParameterizedElement extends Element {
  List<TypeParameterElement> get typeParameters;
}

abstract class TypeAliasElement implements TypeParameterizedElement {
  Element? get aliasedElement;

  /// The aliased type.
  ///
  /// If non-function type aliases feature is enabled for the enclosing library,
  /// this type might be just anything. If the feature is disabled, return
  /// a [FunctionType].
  // DartType get aliasedType;
}

abstract class InstanceElement extends Element implements TypeParameterizedElement {
  List<PropertyAccessorElement> get accessors;

  List<FieldElement> get fields;

  List<MethodElement> get methods;

  DartType get thisType;
}

abstract class InterfaceElement extends InstanceElement with TypeParameterizedElementMixin {
  InterfaceType? get superType;

  List<InterfaceType> get allSuperTypes;

  List<InterfaceType> get mixins;

  List<InterfaceType> get interfaces;

  MethodElement? getMethod(String name) => methods.firstWhereOrNull((e) => e.name == name);

  FieldElement? getField(String name) => fields.firstWhereOrNull((e) => e.name == name);
}

abstract class LibraryElement extends Element {
  AssetSrc get src;

  String get srcId => src.id;

  List<Element> get resolvedElements;

  Iterable<ClassElementImpl> get classes;

  Iterable<MixinElementImpl> get mixins;

  Iterable<EnumElementImpl> get enums;

  Iterable<FunctionElement> get functions;

  ClassElementImpl? getClass(String name);

  InterfaceElement? getInterfaceElement(String name);

  Element? getElement(String name);

  MixinElementImpl? getMixin(String name);

  EnumElementImpl? getEnum(String name);

  FunctionElement? getFunction(String name);
}

abstract class VariableElement extends Element {
  bool get hasImplicitType;

  bool get isConst;

  bool get isFinal;

  bool get isLate;

  bool get isStatic;

  @override
  String get name;

  DartType get type;

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

  List<TypeParameterElement> get typeParameters;
}

abstract class ClassElement extends InterfaceElement {
  List<ConstructorElement> get constructors;

  ConstructorElement? getConstructor(String name);

  ConstructorElement? get unnamedConstructor;
}

abstract class EnumElement implements InterfaceElement {}

abstract class MixinElement implements Element {
  List<InterfaceType> get superclassConstraints;
}

abstract class NullElement extends Element {}
