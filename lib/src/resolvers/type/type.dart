import 'package:code_genie/src/resolvers/element/element.dart';

abstract class DartType {
  String get name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is DartType && runtimeType == other.runtimeType && element == other.element;

  @override
  int get hashCode => 0;

  @override
  String toString() {
    return name;
  }

  Element get element;
}

class TypeRef extends DartType {
  @override
  final String name;

  TypeRef(this.name);

  @override
  Element get element => throw UnimplementedError();
}

abstract class ParameterizedType implements DartType {
  List<DartType> get typeArguments;
}

abstract class InterfaceType implements ParameterizedType {
  @override
  InterfaceElement get element;

  List<InterfaceType> get interfaces;

  List<MethodElement> get methods;

  List<InterfaceType> get mixins;

  InterfaceType? get superclass;

  List<InterfaceType> get superclassConstraints;
}

class InterfaceTypeImpl implements InterfaceType {
  @override
  final String name;

  @override
  final InterfaceElement element;

  @override
  final List<DartType> typeArguments;

  @override
  List<InterfaceType> get interfaces => element.interfaces;

  @override
  List<MethodElement> get methods => element.methods;

  @override
  List<InterfaceType> get mixins => element.mixins;

  @override
  InterfaceType? get superclass => element.superType;

  @override
  List<InterfaceType> get superclassConstraints {
    if (element is MixinElement) {
      return (element as MixinElement).superclassConstraints;
    }
    return const [];
  }

  InterfaceTypeImpl({required this.name, required this.element, this.typeArguments = const []});

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.write(name);
    if (typeArguments.isNotEmpty) {
      buffer.write('<');
      buffer.writeAll(typeArguments.map((e) => e.toString()), ', ');
      buffer.write('>');
    }
    return buffer.toString();
  }
}

class TypeParameterType extends DartType {
  final DartType bound;

  TypeParameterType(this.element, this.bound);

  @override
  final TypeParameterElement element;

  @override
  String get name => element.name;
}

class NeverType extends DartType {
  @override
  final String name = 'Never';

  @override
  Element get element => Element.nullElement;
}

class VoidType extends DartType {
  @override
  final String name = 'void';

  @override
  Element get element => Element.nullElement;
}

class DynamicType extends DartType {
  @override
  final String name = 'dynamic';

  @override
  Element get element => Element.nullElement;
}

abstract class FunctionType implements DartType {
  @override
  NullElement get element;

  Map<String, DartType> get namedParameterTypes;

  List<DartType> get normalParameterTypes;

  List<DartType> get optionalParameterTypes;

  List<ParameterElement> get parameters;

  List<TypeParameterElement> get typeParameters;

  DartType get returnType;
}

class FunctionTypeImpl implements FunctionType {
  @override
  final String name;

  @override
  final NullElement element;

  @override
  final Map<String, DartType> namedParameterTypes;

  @override
  final List<DartType> normalParameterTypes;

  @override
  final List<DartType> optionalParameterTypes;

  @override
  final List<ParameterElement> parameters;

  @override
  final List<TypeParameterElement> typeParameters;

  @override
  final DartType returnType;

  FunctionTypeImpl({
    required this.name,
    required this.element,
    this.namedParameterTypes = const {},
    this.normalParameterTypes = const [],
    this.optionalParameterTypes = const [],
    this.parameters = const [],
    this.typeParameters = const [],
    required this.returnType,
  });
}
