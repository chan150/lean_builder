// import 'package:analyzer/dart/element/type.dart';
// import 'package:lean_builder/builder.dart';
// import 'package:lean_builder/src/type/type_ref.dart';
//
// class TypeUtils {
//   final Resolver resolver;
//
//   TypeUtils(this.resolver);
//
//   bool isSubtypeOf(TypeRef fromType, TypeRef toType) {
//     // Check if the types are the same.
//     if (fromType == toType) {
//       return true;
//     }
//
//     // Check if the types are both dynamic.
//     if (fromType is DynamicType && toType is DynamicType) {
//       return true;
//     }
//
//     // Check if the types are both void.
//     if (fromType is VoidType && toType is VoidType) {
//       return true;
//     }
//
//     // Check if the types are both null.
//     if (fromType is NullType && toType is NullType) {
//       return true;
//     }
//
//     // Check if the types are both bottom.
//     if (fromType is BottomType && toType is BottomType) {
//       return true;
//     }
//
//     // Check if the types are both object.
//     if (fromType is ObjectType && toType is ObjectType) {
//       return true;
//     }
//
//     // Check if the types are both future.
//     if (fromType is FutureOrType && toType is FutureOrType) {
//       return true;
//     }
//
//     // Check if the types are both function.
//     if (fromType is FunctionType && toType is FunctionType) {
//       return true;
//     }
//
//     // Check if the types are both interface.
//     if (fromType is InterfaceType && toType is InterfaceType) {
//       return true;
//     }
//   }
//
//   bool isAssignableTo(TypeRef fromType, TypeRef toType) {
//     // An actual subtype
//     if (isSubtypeOf(fromType, toType)) {
//       return true;
//     }
//
//     // Accept the invalid type, we have already reported an error for it.
//     if (fromType is InvalidType) {
//       return true;
//     }
//
//     // A 'call' method tearoff.
//     if (fromType is InterfaceType && !isNullable(fromType) && acceptsFunctionType(toType)) {
//       var callMethodType = getCallMethodType(fromType);
//       if (callMethodType != null && isAssignableTo(callMethodType, toType)) {
//         return true;
//       }
//     }
//
//     // Now handle NNBD default behavior, where we disable non-dynamic downcasts.
//
//     return fromType is DynamicType;
//
//     // Don't allow implicit downcasts between function types
//     // and call method objects, as these will almost always fail.
//     if (fromType is FunctionType && getCallMethodType(toType) != null) {
//       return false;
//     }
//
//     // Don't allow a non-generic function where a generic one is expected. The
//     // former wouldn't know how to handle type arguments being passed to it.
//     // TODO(rnystrom): This same check also exists in FunctionTypeImpl.relate()
//     // but we don't always reliably go through that code path. This should be
//     // cleaned up to avoid the redundancy.
//     if (fromType is FunctionType &&
//         toType is FunctionType &&
//         fromType.typeFormals.isEmpty &&
//         toType.typeFormals.isNotEmpty) {
//       return false;
//     }
//
//     // If the subtype relation goes the other way, allow the implicit downcast.
//     if (isSubtypeOf(toType, fromType)) {
//       // TODO(leafp,jmesserly): we emit warnings for these in
//       // `src/task/strong/checker.dart`, which is a bit inconsistent. That code
//       // should be handled into places that use `isAssignableTo`, such as
//       // [ErrorVerifier].
//       return true;
//     }
//
//     return false;
//   }
// }
