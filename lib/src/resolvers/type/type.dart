import 'package:analyzer/dart/element/element.dart';

abstract class DartType {
  String get name;

  String get srcId;

  @override
  bool operator ==(Object other) => identical(this, other) || other is DartType && runtimeType == other.runtimeType;

  @override
  int get hashCode => 0;

  @override
  String toString() {
    return name;
  }

  Element? get element;
}

class TypeRef extends DartType {
  @override
  final String name;

  @override
  final String srcId;

  TypeRef(this.name, this.srcId);

  @override
  Element? get element => null;
}

class InterfaceType extends DartType {
  @override
  final String name;
  @override
  final String srcId;

  InterfaceType(this.name, this.srcId);

  @override
  Element? get element => null;
}
