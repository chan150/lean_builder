import 'package:analyzer/dart/ast/ast.dart';
import 'package:collection/collection.dart';
import 'package:lean_builder/element.dart';
import 'package:lean_builder/src/graph/identifier_ref.dart';
import 'package:lean_builder/src/type/type.dart';

import 'const_evaluator.dart';

sealed class Constant {
  const Constant();

  static const Constant invalid = InvalidConst();

  bool get isString => this is ConstString;

  bool get isNum => this is ConstNum;

  bool get isInt => this is ConstInt;

  bool get isDouble => this is ConstDouble;

  bool get isBool => this is ConstBool;

  bool get isSymbol => this is ConstSymbol;

  bool get isTypeRef => this is ConstTypeRef;

  bool get isEnumValue => this is ConstEnumValue;

  bool get isFunctionReference => this is ConstFunctionReference;

  bool get isList => this is ConstList;

  bool get isMap => this is ConstMap;

  bool get isSet => this is ConstSet;

  bool get isObject => this is ConstObject;

  bool get isInvalid => this is InvalidConst;

  Object? get literalValue {
    if (this is ConstLiteral) {
      return (this as ConstLiteral).value;
    }
    return null;
  }
}

class InvalidConst extends Constant {
  const InvalidConst();

  @override
  String toString() => 'INVALID_CONST';

  @override
  bool operator ==(Object other) => identical(this, other) || other is InvalidConst && runtimeType == other.runtimeType;

  @override
  int get hashCode => 0;
}

// represents a primitive constant value
abstract class ConstLiteral<T> extends Constant {
  const ConstLiteral(this.value);

  final T value;
}

class ConstTypeRef extends ConstLiteral<DartType> {
  ConstTypeRef(super.value);

  @override
  String toString() => value.toString();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ConstTypeRef && runtimeType == other.runtimeType && value == other.value;

  @override
  int get hashCode => value.hashCode;
}

class ConstString extends ConstLiteral<String> {
  ConstString(super.value);

  @override
  String toString() => value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ConstString && runtimeType == other.runtimeType && value == other.value;

  @override
  int get hashCode => value.hashCode;
}

class ConstNum extends ConstLiteral<num> {
  ConstNum(super.value);

  @override
  String toString() => value.toString();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ConstNum && runtimeType == other.runtimeType && value == other.value;

  @override
  int get hashCode => value.hashCode;
}

class ConstInt extends ConstLiteral<int> {
  ConstInt(super.value);

  @override
  String toString() => value.toString();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ConstInt && runtimeType == other.runtimeType && value == other.value;

  @override
  int get hashCode => value.hashCode;
}

class ConstDouble extends ConstLiteral<double> {
  ConstDouble(super.value);

  @override
  String toString() => value.toString();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ConstDouble && runtimeType == other.runtimeType && value == other.value;

  @override
  int get hashCode => value.hashCode;
}

class ConstSymbol extends ConstLiteral<String> {
  ConstSymbol(super.value);

  @override
  String toString() => value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ConstSymbol && runtimeType == other.runtimeType && value == other.value;

  @override
  int get hashCode => value.hashCode;
}

class ConstBool extends ConstLiteral<bool> {
  ConstBool(super.value);

  @override
  String toString() => value.toString();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ConstBool && runtimeType == other.runtimeType && value == other.value;

  @override
  int get hashCode => value.hashCode;
}

class ConstEnumValue extends ConstLiteral<String> {
  final String enumName;
  final int index;
  final InterfaceType type;

  ConstEnumValue(this.enumName, super.value, this.index, this.type);

  @override
  String toString() => '$enumName.$value';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConstEnumValue && runtimeType == other.runtimeType && value == other.value && enumName == other.enumName;

  @override
  int get hashCode => value.hashCode ^ enumName.hashCode;
}

abstract class ConstFunctionReference extends Constant {
  String get name;

  DeclarationRef get declaration;

  FunctionType get type;

  List<DartType> get typeArguments;

  ExecutableElement get element;
}

class ConstFunctionReferenceImpl extends ConstFunctionReference {
  @override
  FunctionType get type => element.type;

  @override
  final String name;

  @override
  final DeclarationRef declaration;

  @override
  final ExecutableElement element;

  ConstFunctionReferenceImpl({required this.name, required this.element, required this.declaration});

  @override
  String toString() => name;

  @override
  List<DartType> get typeArguments => _typeArguments;

  final List<DartType> _typeArguments = [];

  void addTypeArgument(DartType type) {
    _typeArguments.add(type);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConstFunctionReferenceImpl &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          name == other.name &&
          declaration == other.declaration &&
          const ListEquality().equals(_typeArguments, other._typeArguments);

  @override
  int get hashCode => type.hashCode ^ name.hashCode ^ declaration.hashCode ^ const ListEquality().hash(_typeArguments);
}

class ConstList extends ConstLiteral<List<Constant>> {
  ConstList(super.value);

  @override
  String toString() => '[${value.map((e) => e.toString()).join(', ')}]';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConstList && runtimeType == other.runtimeType && const ListEquality().equals(value, other.value);

  @override
  int get hashCode => const ListEquality().hash(value);
}

class ConstMap extends ConstLiteral<Map<Constant, Constant>> {
  ConstMap(super.value);

  @override
  String toString() => '{${value.entries.map((e) => '${e.key}: ${e.value}').join(', ')}}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConstMap && runtimeType == other.runtimeType && const MapEquality().equals(value, other.value);

  @override
  int get hashCode => const MapEquality().hash(value);
}

class ConstSet extends ConstLiteral<Set<Constant>> {
  ConstSet(super.value);

  @override
  String toString() => '{${value.map((e) => e.toString()).join(', ')}}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConstSet && runtimeType == other.runtimeType && const SetEquality().equals(value, other.value);

  @override
  int get hashCode => const SetEquality().hash(value);
}

abstract class ConstObject extends Constant {
  ConstObject() : super();

  DartType get type;

  String? get constructorName;

  List<Expression> get constructorArguments;

  Map<String, Constant?> get props;

  Constant? get(String key) => props[key];

  ConstTypeRef? getTypeRef(String key) => props[key] as ConstTypeRef?;

  ConstString? getString(String key);

  ConstInt? getInt(String key);

  ConstDouble? getDouble(String key);

  ConstNum? getNum(String key);

  ConstBool? getBool(String key);

  ConstObject? getObject(String key);

  ConstList? getList(String key);

  ConstMap? getMap(String key);

  ConstSet? getSet(String key);

  ConstEnumValue? getEnumValue(String key);

  ConstFunctionReference? getFunctionReference(String key);
}

class ConstObjectImpl extends ConstObject {
  ConstObjectImpl(
    this.props,
    this.type, {
    this.positionalNames = const {},
    this.constructorName,
    this.constructorArguments = const [],
  });

  @override
  final DartType type;

  @override
  final Map<String, Constant?> props;

  final Map<int, String> positionalNames;

  @override
  String toString() => '{${props.entries.map((e) => '${e.key}: ${e.value}').join(', ')}}';

  @override
  ConstString? getString(String key) => _getTyped<ConstString>(key);

  @override
  ConstInt? getInt(String key) => _getTyped<ConstInt>(key);

  @override
  ConstDouble? getDouble(String key) => _getTyped<ConstDouble>(key);

  @override
  ConstNum? getNum(String key) => _getTyped<ConstNum>(key);

  @override
  ConstBool? getBool(String key) => _getTyped<ConstBool>(key);

  @override
  ConstObject? getObject(String key) => _getTyped<ConstObject>(key);

  @override
  ConstList? getList(String key) => _getTyped<ConstList>(key);

  @override
  ConstMap? getMap(String key) => _getTyped<ConstMap>(key);

  @override
  ConstSet? getSet(String key) => _getTyped<ConstSet>(key);

  @override
  ConstEnumValue? getEnumValue(String key) => _getTyped<ConstEnumValue>(key);

  @override
  ConstFunctionReference? getFunctionReference(String key) => _getTyped<ConstFunctionReference>(key);

  T? _getTyped<T extends Constant>(String key) {
    final value = props[key];
    if (value == null) {
      return null;
    }
    if (value is T) {
      return value;
    }
    throw Exception('Value for $key is expected to be $T, but got ${value.runtimeType}');
  }

  ConstObjectImpl construct(ArgumentList args, String? name, ConstantEvaluator evaluator) {
    final props = Map.of(this.props);
    for (var i = 0; i < args.arguments.length; i++) {
      final arg = args.arguments[i];
      if (arg is NamedExpression) {
        final name = arg.name.label.name;
        props[name] = evaluator.evaluate(arg.expression);
      } else {
        final name = positionalNames[i];
        if (name != null) {
          props[name] = evaluator.evaluate(arg);
        }
      }
    }
    return ConstObjectImpl(
      props,
      type,
      positionalNames: positionalNames,
      constructorName: name,
      constructorArguments: List.of(args.arguments),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConstObjectImpl &&
          runtimeType == other.runtimeType &&
          const MapEquality().equals(props, other.props) &&
          type == other.type;

  @override
  int get hashCode => const MapEquality().hash(props) ^ type.hashCode;

  @override
  final List<Expression> constructorArguments;

  @override
  final String? constructorName;
}
