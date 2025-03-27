import 'package:code_genie/src/resolvers/element.dart';

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
  final List<InterfaceType> superclassConstraints;

  InterfaceTypeImpl({
    required this.name,
    required this.element,
    this.typeArguments = const [],
    this.superclassConstraints = const [],
  });

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

class NeverType extends DartType {
  @override
  final String name = 'Never';

  @override
  Element get element => NullElement();
}

class VoidType extends DartType {
  @override
  final String name = 'void';

  @override
  Element get element => NullElement();
}

class DynamicType extends DartType {
  @override
  final String name = 'dynamic';

  @override
  Element get element => NullElement();
}
