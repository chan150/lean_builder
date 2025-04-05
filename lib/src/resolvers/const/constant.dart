import 'package:code_genie/src/resolvers/type/type.dart';

abstract class Constant<T> {
  const Constant(this.value);

  final T value;

  static const Constant invalid = _InvalidConstValue();
}

class _InvalidConstValue extends Constant<Null> {
  const _InvalidConstValue() : super(null);

  @override
  String toString() => 'INVALID_CONST';
}

// represents a primitive constant value
abstract class ConstValue<T> extends Constant<T> {
  const ConstValue(super.value);
}

class ConstString extends ConstValue<String> {
  ConstString(super.value);

  @override
  String toString() => '"$value"';
}

class ConstNum extends ConstValue<num> {
  ConstNum(super.value);

  @override
  String toString() => value.toString();
}

class ConstInt extends ConstValue<int> {
  ConstInt(super.value);

  @override
  String toString() => value.toString();
}

class ConstDouble extends ConstValue<double> {
  ConstDouble(super.value);

  @override
  String toString() => value.toString();
}

class ConstSymbol extends ConstValue<String> {
  ConstSymbol(super.value);

  @override
  String toString() => "'$value'";
}

class ConstBool extends ConstValue<bool> {
  ConstBool(super.value);

  @override
  String toString() => value.toString();
}

class ConstEnumValue extends ConstValue<String> {
  final String enumName;

  ConstEnumValue(this.enumName, super.value);

  @override
  String toString() => '$enumName.$value';
}

abstract class ConstFunctionReference extends Constant<String> {
  const ConstFunctionReference(super.value);

  FunctionType? get type;

  List<DartType> get typeArguments;
}

class ConstFunctionReferenceImpl extends ConstFunctionReference {
  @override
  final FunctionType? type;

  ConstFunctionReferenceImpl(super.value, this.type);

  @override
  String toString() => value;

  @override
  List<DartType> get typeArguments => _typeArguments;

  final List<DartType> _typeArguments = [];

  void addTypeArgument(DartType type) {
    _typeArguments.add(type);
  }
}

class ConstList extends Constant<List<Constant>> {
  ConstList(super.value);

  @override
  String toString() => '[${value.map((e) => e.toString()).join(', ')}]';
}

class ConstMap extends Constant<Map<String, Constant>> {
  ConstMap(super.value);

  @override
  String toString() => '{${value.entries.map((e) => '${e.key}: ${e.value}').join(', ')}}';
}

class ConstSet extends Constant<Set<Constant>> {
  ConstSet(super.value);

  @override
  String toString() => '{${value.map((e) => e.toString()).join(', ')}}';
}

abstract class ConstObject extends Constant<Null> {
  ConstObject() : super(null);

  Map<String, Constant> get props;

  ConstString? getString(String key);

  ConstInt? getInt(String key);

  ConstDouble? getDouble(String key);

  ConstNum? getNum(String key);

  ConstBool? getBool(String key);

  ConstObject? getObject(String key);

  ConstList? getList(String key);

  ConstMap? getMap(String key);

  ConstSet? getSet(String key);
}
