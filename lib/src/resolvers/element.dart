import 'package:code_genie/src/resolvers/file_asset.dart';
import 'package:code_genie/src/resolvers/type/type.dart';
import 'package:collection/collection.dart';

abstract class Element {
  String get name;

  @override
  String toString() => name;

  Element? get enclosingElement;

  LibraryElement get library;

  String get identifier => '${library.src}#$name';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Element && runtimeType == other.runtimeType && identifier == other.identifier;

  @override
  int get hashCode => name.hashCode ^ library.hashCode;
}

class TypeParameterElement extends Element {
  @override
  final Element enclosingElement;
  @override
  final String name;

  final DartType? bound;

  TypeParameterElement(this.enclosingElement, this.name, [this.bound]);

  @override
  LibraryElement get library => enclosingElement.library;
}

abstract class TypeParametrizedElement extends Element {
  List<TypeParameterElement> get typeParameters;
}

mixin TypeParameterizedElementMixin on Element implements TypeParametrizedElement {
  final List<TypeParameterElement> _typeParameters = [];

  @override
  List<TypeParameterElement> get typeParameters => _typeParameters;

  void addTypeParameter(TypeParameterElement typeParameter) {
    _typeParameters.add(typeParameter);
  }
}

abstract class InterfaceElement extends Element with TypeParameterizedElementMixin {
  List<MethodElement> get methods;

  List<FieldElement> get fields;

  InterfaceType? get superType;

  List<InterfaceType> get allSuperTypes;

  List<InterfaceType> get mixins;

  List<InterfaceType> get interfaces;

  MethodElement? getMethod(String name) => methods.firstWhereOrNull((e) => e.name == name);

  FieldElement? getField(String name) => fields.firstWhereOrNull((e) => e.name == name);

  String toShortString() {
    final buffer = StringBuffer();
    buffer.write(name);
    if (superType != null) {
      buffer.write(' extends ${superType!.name}');
    }
    if (typeParameters.isNotEmpty) {
      buffer.write('<${typeParameters.map((e) => '${e.name} extends ${e.bound?.name}').join(', ')}>');
    }
    if (interfaces.isNotEmpty) {
      buffer.write(' implements ${interfaces.map((e) => e.name).join(', ')}');
    }
    if (mixins.isNotEmpty) {
      buffer.write(' with ${mixins.map((e) => e.name).join(', ')}');
    }
    return buffer.toString();
  }
}

class LibraryElement extends Element {
  LibraryElement({required this.name, required this.src});

  @override
  final String name;

  final AssetFile src;

  String get srcId => src.id;

  @override
  Null get enclosingElement => null;

  @override
  LibraryElement get library => this;

  List<Element> resolvedElements = [];

  Iterable<ClassElementImpl> get classes => resolvedElements.whereType<ClassElementImpl>();

  ClassElementImpl? getClass(String name) => classes.firstWhereOrNull((e) => e.name == name);

  InterfaceElement? getInterfaceElement(String name) {
    return resolvedElements.whereType<InterfaceElement>().firstWhereOrNull((e) => e.name == name);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other && other is LibraryElement && runtimeType == other.runtimeType && src.id == other.src.id;

  @override
  int get hashCode => src.id.hashCode;

  Element? getElement(String name) {
    return resolvedElements.firstWhereOrNull((e) => e.name == name);
  }
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
}

abstract class ClassMemberElement extends Element {
  bool get isStatic;

  @override
  Element get enclosingElement;
}

class FieldElement extends ClassMemberElement implements VariableElement {
  FieldElement({
    required this.isStatic,
    required this.name,
    required this.isAbstract,
    required this.library,
    required this.isCovariant,
    required this.isEnumConstant,
    required this.isExternal,
    required this.enclosingElement,
    required this.hasImplicitType,
    required this.isConst,
    required this.isFinal,
    required this.isLate,
    required this.type,
  });

  @override
  final Element enclosingElement;

  @override
  final bool hasImplicitType;

  @override
  final bool isConst;

  @override
  final bool isFinal;

  @override
  final bool isLate;

  @override
  final DartType type;

  @override
  final bool isStatic;

  @override
  final String name;

  final bool isAbstract;
  final bool isCovariant;
  final bool isEnumConstant;
  final bool isExternal;

  @override
  final LibraryElement library;
}

class ParameterElement extends VariableElement {
  ParameterElement({
    required this.name,
    required this.library,
    required this.enclosingElement,
    required this.hasImplicitType,
    required this.isConst,
    required this.isFinal,
    required this.isLate,
    required this.type,
  });

  @override
  final ClassElement enclosingElement;

  @override
  final bool hasImplicitType;

  @override
  final bool isConst;

  @override
  final bool isFinal;

  @override
  final bool isLate;

  @override
  final DartType type;

  @override
  final String name;

  @override
  final LibraryElement library;

  @override
  bool get isStatic => false;
}

class MethodElement extends ClassMemberElement {
  MethodElement({
    required this.isStatic,
    required this.name,
    required this.library,
    required this.enclosingElement,
    required this.returnType,
  });

  @override
  final ClassElement enclosingElement;

  @override
  final bool isStatic;

  @override
  final String name;

  List<ParameterElement> parameters = [];

  final DartType returnType;

  @override
  final LibraryElement library;
}

abstract class ClassElement extends InterfaceElement {}

class ClassElementImpl extends InterfaceElementImpl {
  ClassElementImpl({required super.name, required super.library});
}

class InterfaceElementImpl extends InterfaceElement {
  final List<InterfaceType> _mixins = [];
  final List<InterfaceType> _interfaces = [];
  final List<MethodElement> _methods = [];
  final List<FieldElement> _fields = [];

  InterfaceElementImpl({required this.name, required this.library});

  @override
  List<FieldElement> get fields => _fields;

  @override
  List<MethodElement> get methods => _methods;

  @override
  List<InterfaceType> get interfaces => _interfaces;

  @override
  List<InterfaceType> get mixins => _mixins;

  @override
  List<TypeParameterElement> get typeParameters => _typeParameters;

  void addMixin(InterfaceType mixin) {
    _mixins.add(mixin);
  }

  void addInterface(InterfaceType interface) {
    _interfaces.add(interface);
  }

  void addMethod(MethodElement method) {
    _methods.add(method);
  }

  void addField(FieldElement field) {
    _fields.add(field);
  }

  @override
  List<InterfaceType> get allSuperTypes => throw UnimplementedError();

  @override
  final String name;

  @override
  final LibraryElement library;

  @override
  Element? get enclosingElement => library;

  InterfaceType? _superType;

  set superType(InterfaceType? value) {
    _superType = value;
  }

  @override
  InterfaceType? get superType => _superType;
}

class NullElement extends Element {
  @override
  final String name = 'Null';

  @override
  final Element? enclosingElement = null;

  @override
  final LibraryElement library = throw UnimplementedError();

  @override
  bool operator ==(Object other) => other is NullElement;

  @override
  int get hashCode => name.hashCode;
}
