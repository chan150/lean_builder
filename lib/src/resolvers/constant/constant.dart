import 'package:analyzer/dart/ast/ast.dart';
import 'package:collection/collection.dart';
import 'package:lean_builder/src/resolvers/type/type_ref.dart';
import 'package:lean_builder/src/scanner/identifier_ref.dart';

import 'const_evaluator.dart';

sealed class Constant {
  const Constant();

  static const Constant invalid = InvalidConst();
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
abstract class ConstValue<T> extends Constant {
  const ConstValue(this.value);

  final T value;
}

class ConstTypeRef extends ConstValue<TypeRef> {
  ConstTypeRef(super.value);

  @override
  String toString() => value.toString();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ConstTypeRef && runtimeType == other.runtimeType && value == other.value;

  @override
  int get hashCode => value.hashCode;
}

class ConstString extends ConstValue<String> {
  ConstString(super.value);

  @override
  String toString() => value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ConstString && runtimeType == other.runtimeType && value == other.value;

  @override
  int get hashCode => value.hashCode;
}

class ConstNum extends ConstValue<num> {
  ConstNum(super.value);

  @override
  String toString() => value.toString();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ConstNum && runtimeType == other.runtimeType && value == other.value;

  @override
  int get hashCode => value.hashCode;
}

class ConstInt extends ConstValue<int> {
  ConstInt(super.value);

  @override
  String toString() => value.toString();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ConstInt && runtimeType == other.runtimeType && value == other.value;

  @override
  int get hashCode => value.hashCode;
}

class ConstDouble extends ConstValue<double> {
  ConstDouble(super.value);

  @override
  String toString() => value.toString();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ConstDouble && runtimeType == other.runtimeType && value == other.value;

  @override
  int get hashCode => value.hashCode;
}

class ConstSymbol extends ConstValue<String> {
  ConstSymbol(super.value);

  @override
  String toString() => value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ConstSymbol && runtimeType == other.runtimeType && value == other.value;

  @override
  int get hashCode => value.hashCode;
}

class ConstBool extends ConstValue<bool> {
  ConstBool(super.value);

  @override
  String toString() => value.toString();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ConstBool && runtimeType == other.runtimeType && value == other.value;

  @override
  int get hashCode => value.hashCode;
}

class ConstEnumValue extends ConstValue<String> {
  final String enumName;

  ConstEnumValue(this.enumName, super.value);

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

  DeclarationRef get src;

  FunctionTypeRef get type;

  List<TypeRef> get typeArguments;
}

class ConstFunctionReferenceImpl extends ConstFunctionReference {
  @override
  final FunctionTypeRef type;
  @override
  final String name;

  @override
  final DeclarationRef src;

  ConstFunctionReferenceImpl(this.name, this.type, this.src);

  @override
  String toString() => name;

  @override
  List<TypeRef> get typeArguments => _typeArguments;

  final List<TypeRef> _typeArguments = [];

  void addTypeArgument(TypeRef type) {
    _typeArguments.add(type);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConstFunctionReferenceImpl &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          name == other.name &&
          src == other.src &&
          const ListEquality().equals(_typeArguments, other._typeArguments);

  @override
  int get hashCode => type.hashCode ^ name.hashCode ^ src.hashCode ^ const ListEquality().hash(_typeArguments);
}

class ConstList extends ConstValue<List<Constant>> {
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

class ConstMap extends ConstValue<Map<String, Constant>> {
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

class ConstSet extends ConstValue<Set<Constant>> {
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

abstract class ConstObject extends ConstValue<Null> {
  ConstObject() : super(null);

  TypeRef get type;

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

  ConstFunctionReference? getFunctionReference(String key);
}

class ConstObjectImpl extends ConstObject {
  ConstObjectImpl(this.props, this.type, {this.positionalNames = const {}});

  @override
  final TypeRef type;

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
  ConstFunctionReference? getFunctionReference(String key) => _getTyped<ConstFunctionReference>(key);

  T? _getTyped<T extends Constant>(String key) {
    final value = props[key];
    if (value is T) {
      return value;
    }
    throw Exception('Value for $key is not of type $T');
  }

  ConstObjectImpl mergeArgs(ArgumentList args, ConstantEvaluator evaluator) {
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
    return ConstObjectImpl(props, type, positionalNames: positionalNames);
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
}
