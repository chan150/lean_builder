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

  static final dynamicType = DynamicType();

  static final voidType = VoidType();

  static final neverType = NeverType();
}

abstract class ParameterizedType implements DartType {
  List<DartType> get typeArguments;
}

mixin ParameterizedTypeMixin implements ParameterizedType {
  @override
  List<DartType> get typeArguments => _typeArguments;

  final List<DartType> _typeArguments = [];

  void addTypeArgument(DartType typeArgument) {
    _typeArguments.add(typeArgument);
  }
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

class InterfaceTypeImpl with ParameterizedTypeMixin implements InterfaceType {
  @override
  final InterfaceElement element;

  @override
  String get name => element.name;

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

  @override
  final List<DartType> typeArguments;

  InterfaceTypeImpl(this.element, [this.typeArguments = const []]);

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
  NullElement get element => Element.nullElement;

  @override
  Map<String, DartType> get namedParameterTypes {
    final Map<String, DartType> namedParameters = {};
    for (final parameter in parameters) {
      if (true) {
        namedParameters[parameter.name] = parameter.type;
      }
    }
    return namedParameters;
  }

  @override
  List<DartType> get normalParameterTypes => List.unmodifiable(parameters.map((e) => e.type));

  @override
  List<DartType> get optionalParameterTypes => [];

  @override
  final List<ParameterElement> parameters;

  @override
  List<TypeParameterElement> typeParameters;

  @override
  final DartType returnType;

  FunctionTypeImpl({
    required this.name,
    this.parameters = const [],
    this.typeParameters = const [],
    required this.returnType,
  });

  @override
  String toString() {
    final buffer = StringBuffer();
    print(name);
    buffer.write(returnType.toString());
    buffer.write(' Function');
    if (typeParameters.isNotEmpty) {
      buffer.write('<');
      buffer.writeAll(typeParameters.map((e) => e.toString()), ', ');
      buffer.write('>');
    }
    buffer.write('(');
    buffer.writeAll(normalParameterTypes.map((e) => e.toString()), ', ');
    if (optionalParameterTypes.isNotEmpty) {
      buffer.write('[');
      buffer.writeAll(optionalParameterTypes.map((e) => e.toString()), ', ');
      buffer.write(']');
    }
    if (namedParameterTypes.isNotEmpty) {
      buffer.write('{');
      buffer.writeAll(namedParameterTypes.entries.map((e) => '${e.key}: ${e.value}'), ', ');
      buffer.write('}');
    }
    buffer.write(')');
    return buffer.toString();
  }
}
