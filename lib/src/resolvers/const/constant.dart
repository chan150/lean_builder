import 'package:analyzer/dart/ast/ast.dart';
import 'package:code_genie/src/resolvers/const/const_evaluator.dart';
import 'package:code_genie/src/resolvers/type/type_ref.dart';
import 'package:code_genie/src/scanner/identifier_ref.dart';

abstract class Constant {
  const Constant();

  static const Constant invalid = _InvalidConstValue();
}

class _InvalidConstValue extends Constant {
  const _InvalidConstValue();

  @override
  String toString() => 'INVALID_CONST';
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
}

class ConstString extends ConstValue<String> {
  ConstString(super.value);

  @override
  String toString() => value;
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

abstract class ConstFunctionReference extends Constant {
  String get name;

  IdentifierLocation get src;

  FunctionTypeRef get type;

  List<TypeRef> get typeArguments;
}

class ConstFunctionReferenceImpl extends ConstFunctionReference {
  @override
  final FunctionTypeRef type;
  @override
  final String name;

  @override
  final IdentifierLocation src;

  ConstFunctionReferenceImpl(this.name, this.type, this.src);

  @override
  String toString() => name;

  @override
  List<TypeRef> get typeArguments => _typeArguments;

  final List<TypeRef> _typeArguments = [];

  void addTypeArgument(TypeRef type) {
    _typeArguments.add(type);
  }
}

class ConstList extends ConstValue<List<Constant>> {
  ConstList(super.value);

  @override
  String toString() => '[${value.map((e) => e.toString()).join(', ')}]';
}

class ConstMap extends ConstValue<Map<String, Constant>> {
  ConstMap(super.value);

  @override
  String toString() => '{${value.entries.map((e) => '${e.key}: ${e.value}').join(', ')}}';
}

class ConstSet extends ConstValue<Set<Constant>> {
  ConstSet(super.value);

  @override
  String toString() => '{${value.map((e) => e.toString()).join(', ')}}';
}

abstract class ConstObject extends ConstValue<Null> {
  ConstObject() : super(null);

  TypeRef get type;

  Map<String, Constant?> get props;

  Constant? get(String key) => props[key];

  ConstString? getString(String key);

  ConstInt? getInt(String key);

  ConstDouble? getDouble(String key);

  ConstNum? getNum(String key);

  ConstBool? getBool(String key);

  ConstObject? getObject(String key);

  ConstList? getList(String key);

  ConstMap? getMap(String key);

  ConstSet? getSet(String key);

  ConstFunctionReference getFunctionReference(String key);
}

class ConstObjectImpl extends ConstObject {
  ConstObjectImpl(this.props, this._positionalNames, this.type);

  @override
  final TypeRef type;

  @override
  final Map<String, Constant?> props;

  final Map<int, String> _positionalNames;

  @override
  String toString() => '{${props.entries.map((e) => '${e.key}: ${e.value}').join(', ')}}';

  @override
  ConstString? getString(String key) => props[key] as ConstString?;

  @override
  ConstInt? getInt(String key) => props[key] as ConstInt?;

  @override
  ConstDouble? getDouble(String key) => props[key] as ConstDouble?;

  @override
  ConstNum? getNum(String key) => props[key] as ConstNum?;

  @override
  ConstBool? getBool(String key) => props[key] as ConstBool?;

  @override
  ConstObject? getObject(String key) => props[key] as ConstObject?;

  @override
  ConstList? getList(String key) => props[key] as ConstList?;

  @override
  ConstMap? getMap(String key) => props[key] as ConstMap?;

  @override
  ConstSet? getSet(String key) => props[key] as ConstSet?;

  @override
  ConstFunctionReference getFunctionReference(String key) {
    final value = props[key];
    if (value is ConstFunctionReference) {
      return value;
    }
    throw Exception('Value for $key is not a function reference');
  }

  ConstObjectImpl mergeArgs(ArgumentList args, ConstantEvaluator evaluator) {
    for (var i = 0; i < args.arguments.length; i++) {
      final arg = args.arguments[i];
      if (arg is NamedExpression) {
        final name = arg.name.label.name;
        props[name] = evaluator.evaluate(arg.expression);
      } else {
        final name = _positionalNames[i];
        if (name != null) {
          props[name] = evaluator.evaluate(arg);
        }
      }
    }
    return this;
  }
}
