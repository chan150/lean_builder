// import 'package:lean_builder/src/resolvers/element/element.dart';
// import 'package:lean_builder/src/resolvers/type/type_ref.dart';
//
// abstract class DartType {
//   String get name;
//
//   InstantiatedTypeAlias? get alias;
//
//   Element? get element;
//
//   bool get isNullable;
//
//   static final dynamicType = DynamicType();
//
//   static final voidType = VoidType();
//
//   static final neverType = NeverType();
// }
//
// class InstantiatedTypeAlias {
//   final TypeAliasElement element;
//   final List<TypeRef> typeArguments;
//
//   InstantiatedTypeAlias(this.element, this.typeArguments);
// }
//
// abstract class ParameterizedType implements DartType {
//   List<DartType> get typeArguments;
// }
//
// mixin ParameterizedTypeMixin implements ParameterizedType {
//   @override
//   List<DartType> get typeArguments => _typeArguments;
//
//   final List<DartType> _typeArguments = [];
//
//   void addTypeArgument(DartType typeArgument) {
//     _typeArguments.add(typeArgument);
//   }
// }
//
// abstract class InterfaceType implements ParameterizedType {
//   @override
//   InterfaceElement get element;
//
//
//   List<MethodElement> get methods;
//
//   List<InterfaceType> get interfaces;
//   List<InterfaceType> get mixins;
//
//   InterfaceType? get superclass;
//
//   List<InterfaceType> get superclassConstraints;
// }
//
// abstract class DartTypeImpl extends DartType {
//   @override
//   bool operator ==(Object other) =>
//       identical(this, other) || other is DartType && runtimeType == other.runtimeType && element == other.element;
//
//   @override
//   int get hashCode => 0;
//
//   @override
//   String toString() {
//     return name + (isNullable ? '?' : '');
//   }
//
//   @override
//   InstantiatedTypeAlias? get alias => _alias;
//
//   InstantiatedTypeAlias? _alias;
//
//   set alias(InstantiatedTypeAlias? value) {
//     _alias = value;
//   }
// }
//
// class InterfaceTypeImpl extends DartTypeImpl with ParameterizedTypeMixin implements InterfaceType {
//   @override
//   final InterfaceElement element;
//
//   @override
//   String get name => element.name;
//
//   @override
//   List<InterfaceType> get interfaces => element.interfaces;
//
//   @override
//   List<MethodElement> get methods => element.methods;
//
//   @override
//   List<InterfaceType> get mixins => element.mixins;
//
//   @override
//   InterfaceType? get superclass => element.superType;
//
//   @override
//   List<InterfaceType> get superclassConstraints {
//     if (element is MixinElement) {
//       return (element as MixinElement).superclassConstraints;
//     }
//     return constant [];
//   }
//
//   @override
//   final List<DartType> typeArguments;
//
//   @override
//   final InstantiatedTypeAlias? alias;
//
//   @override
//   final bool isNullable;
//
//   InterfaceTypeImpl(this.element, {this.typeArguments = constant [], required this.isNullable, this.alias});
//
//   @override
//   String toString() {
//     final buffer = StringBuffer();
//     buffer.write(name);
//
//     if (typeArguments.isNotEmpty) {
//       buffer.write('<');
//       buffer.writeAll(typeArguments.map((e) => e.toString()), ', ');
//       buffer.write('>');
//     }
//     if (isNullable) {
//       buffer.write('?');
//     }
//     return buffer.toString();
//   }
// }
//
// class TypeParameterType extends DartTypeImpl {
//   final DartType bound;
//
//   TypeParameterType(this.element, {required this.bound, required this.isNullable});
//
//   @override
//   final TypeParameterElement element;
//
//   @override
//   String get name => element.name;
//   @override
//   final bool isNullable;
// }
//
// class NeverType extends DartTypeImpl {
//   @override
//   final String name = 'Never';
//
//   @override
//   Null get element => null;
//
//   @override
//   bool get isNullable => false;
// }
//
// class VoidType extends DartTypeImpl {
//   @override
//   final String name = 'void';
//
//   @override
//   Null get element => null;
//
//   @override
//   bool get isNullable => false;
// }
//
// class DynamicType extends DartTypeImpl {
//   @override
//   final String name = 'dynamic';
//
//   @override
//   Null get element => null;
//
//   @override
//   bool get isNullable => true;
// }
//
// abstract class FunctionType implements DartType {
//
//   Map<String, DartType> get namedParameterTypes;
//
//   List<DartType> get normalParameterTypes;
//
//   List<DartType> get optionalParameterTypes;
//
//   List<ParameterElement> get parameters;
//
//   List<TypeParameterElement> get typeParameters;
//
//   DartType get returnType;
// }
//
// class FunctionTypeImpl extends DartTypeImpl implements FunctionType {
//   @override
//   final String name;
//
//   @override
//   Null get element => null;
//
//   @override
//   final bool isNullable;
//
//   @override
//   Map<String, DartType> get namedParameterTypes {
//     final Map<String, DartType> namedParameters = {};
//     // for (final parameter in parameters) {
//     //   if (parameter.isNamed) {
//     //     namedParameters[parameter.name] = parameter.type;
//     //   }
//     // }
//     return namedParameters;
//   }
//
//   @override
//   List<DartType> get normalParameterTypes => List.unmodifiable(
//     parameters.where((e) => !e.isOptional && !e.isNamed).map((e) {
//       return e.type;
//     }),
//   );
//
//   @override
//   List<DartType> get optionalParameterTypes => List.unmodifiable(
//     parameters.where((e) => e.isOptional && !e.isNamed).map((e) {
//       return e.type;
//     }),
//   );
//
//   @override
//   final List<ParameterElement> parameters;
//
//   @override
//   List<TypeParameterElement> typeParameters;
//
//   @override
//   final DartType returnType;
//
//   @override
//   final InstantiatedTypeAlias? alias;
//
//   FunctionTypeImpl({
//     required this.name,
//     this.parameters = constant [],
//     this.typeParameters = constant [],
//     required this.returnType,
//     required this.isNullable,
//     this.alias,
//   });
//
//   @override
//   String toString() {
//     final buffer = StringBuffer();
//     buffer.write(returnType.toString());
//     buffer.write(' $name');
//     if (typeParameters.isNotEmpty) {
//       buffer.write('<');
//       buffer.writeAll(typeParameters.map((e) => e.toString()), ', ');
//       buffer.write('>');
//     }
//     buffer.write('(');
//     if (normalParameterTypes.isNotEmpty) {
//       buffer.writeAll(normalParameterTypes.map((e) => e.toString()), ', ');
//     }
//     if (optionalParameterTypes.isNotEmpty) {
//       buffer.write('[');
//       buffer.writeAll(optionalParameterTypes.map((e) => e.toString()), ', ');
//       buffer.write(']');
//     }
//     if (namedParameterTypes.isNotEmpty) {
//       buffer.write('{');
//       buffer.writeAll(namedParameterTypes.entries.map((e) => '${e.value} ${e.key}'), ', ');
//       buffer.write('}');
//     }
//     buffer.write(')');
//     if (isNullable) {
//       buffer.write('?');
//     }
//     return buffer.toString();
//   }
// }
