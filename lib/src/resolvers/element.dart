import 'package:code_genie/src/resolvers/type/type.dart';

abstract class Element {
  String get name;

  @override
  bool operator ==(Object other) => identical(this, other) || other is Element && runtimeType == other.runtimeType;

  @override
  int get hashCode => 0;

  @override
  String toString() => name;

  Element? get enclosingElement;

  LibraryElement get library;
}

class LibraryElement extends Element {
  LibraryElement({required this.name, required this.srcId, required this.topLevelElements});

  @override
  final String name;

  final String srcId;

  @override
  Null get enclosingElement => null;

  @override
  LibraryElement get library => this;

  final List<Element> topLevelElements;

  Iterable<ClassElement> get classes => topLevelElements.whereType<ClassElement>();
}

abstract class VariableElement implements Element {
  bool get hasImplicitType;

  bool get isConst;

  bool get isFinal;

  bool get isLate;

  bool get isStatic;

  @override
  String get name;

  DartType get type;
}

abstract class ClassMemberElement implements Element {
  bool get isStatic;

  @override
  ClassElement get enclosingElement;
}

class FieldElement implements ClassMemberElement, VariableElement {
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

class ParameterElement implements VariableElement {
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

class MethodElement implements ClassMemberElement {
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

class ClassElement extends Element {
  List<FieldElement> fields = [];
  List<MethodElement> methods = [];

  ClassElement({required this.name, required this.library});

  @override
  final String name;

  @override
  final LibraryElement library;

  @override
  Element? get enclosingElement => library;
}
