// // Copyright (c) 2020, the Dart project authors. Please see the AUTHORS file
// // for details. All rights reserved. Use of this source code is governed by a
// // BSD-style license that can be found in the LICENSE file.
//
// import 'package:lean_builder/builder.dart';
// import 'package:lean_builder/element.dart';
// import 'package:lean_builder/src/graph/identifier_ref.dart';
// import 'package:lean_builder/src/graph/scan_results.dart';
// import 'package:lean_builder/src/type/type_ref.dart';
// import 'package:lean_builder/src/type/type_ref.dart';
//
// /// Helper for checking the subtype relation.
// ///
// /// https://github.com/dart-lang/language
// /// See `resources/type-system/subtyping.md`
// class SubtypeHelper {
//   SubtypeHelper(this.resolver);
//   final Resolver resolver;
//
//   bool isExact(TypeRef T0_, TypeRef T1_) {
//     return T0_ == T1_;
//   }
//
//   /// Return `true` if [T0_] is a subtype of [T1_].
//   bool isSubtypeOf(TypeRef T0_, TypeRef T1_) {
//     // Reflexivity: if `T0` and `T1` are the same type then `T0 <: T1`.
//     if (isExact(T0_, T1_)) {
//       return true;
//     }
//
//     // // `_` is treated as a top and a bottom type during inference.
//     // if (isExact(T0_, UnknownInferredType.instance) ||
//     //     isExact(T1_, UnknownInferredType.instance)) {
//     //   return true;
//     // }
//
//     // `InvalidType` is treated as a top and a bottom type.
//     if (isExact(T0_, TypeRef.invalidType) || isExact(T1_, TypeRef.invalidType)) {
//       return true;
//     }
//
//     // Right Top: if `T1` is a top type (i.e. `dynamic`, or `void`, or
//     // `Object?`) then `T0 <: T1`.
//     if (isExact(T1_, TypeRef.dynamicType) ||
//         isExact(T1_, TypeRef.invalidType) ||
//         isExact(T1_, TypeRef.voidType) ||
//         T1_.isNullable && T1_.isDartCoreObject) {
//       return true;
//     }
//
//     // Left Top: if `T0` is `dynamic` or `void`,
//     //   then `T0 <: T1` if `Object? <: T1`.
//     if (isExact(T0_, TypeRef.dynamicType) || isExact(T0_, TypeRef.invalidType) || isExact(T0_, TypeRef.voidType)) {
//       if (isSubtypeOf(_objectQuestion, T1_)) {
//         return true;
//       }
//     }
//
//     // Left Bottom: if `T0` is `Never`, then `T0 <: T1`.
//     if (isExact(T0_, TypeRef.neverType)) {
//       return true;
//     }
//
//     // Right Object: if `T1` is `Object` then:
//     if (!T1_.isNullable && T1_.isDartCoreObject) {
//       // * if `T0` is an unpromoted type variable with bound `B`,
//       //   then `T0 <: T1` iff `B <: Object`.
//       // * if `T0` is a promoted type variable `X & S`,
//       //   then `T0 <: T1` iff `S <: Object`.
//       if (!T0_.isNullable && T0_ is TypeParameterTypeRef) {
//         var B = T0_.bound;
//         return isSubtypeOf(B, _objectNone);
//       }
//       // * if `T0` is `FutureOr<S>` for some `S`,
//       //   then `T0 <: T1` iff `S <: Object`
//       if (!T0_.isNullable && T0_ is NamedTypeRef && T0_.kind.isInterface && T0_.isDartAsyncFutureOr) {
//         return isSubtypeOf(T0_.typeArguments[0], T1_);
//       }
//
//       // * if `T0` is `Null`, `dynamic`, `void`, or `S?` for any `S`,
//       //   then the subtyping does not hold, the result is false.
//       if (!T0_.isNullable && T0_.isDartCoreNull ||
//           isExact(T0_, TypeRef.dynamicType) ||
//           isExact(T0_, TypeRef.invalidType) ||
//           isExact(T0_, TypeRef.voidType) ||
//           T0_.isNullable) {
//         return false;
//       }
//       // Extension types:
//       //   If `R` is a non-nullable type then `V0` is a proper subtype
//       //   of `Object`, and a non-nullable type.
//       if (T0_ is NamedTypeRef && T0_.kind == TypeKind.extensionKind) {
//         if (T0_.representationType case final representationType?) {
//           if (_typeSystem.isNullable(representationType)) {
//             return false;
//           }
//         }
//       }
//       // Otherwise `T0 <: T1` is true.
//       return true;
//     }
//
//     // Left Null: if `T0` is `Null` then:
//     if (!T0_.isNullable && T0_.isDartCoreNull) {
//       // * If `T1` is `FutureOr<S>` for some `S`, then the query is true iff
//       // `Null <: S`.
//       if (!T1_.isNullable && T1_ is NamedTypeRef && T1_.isDartAsyncFutureOr) {
//         var S = T1_.typeArguments[0];
//         return isSubtypeOf(_nullNone, S);
//       }
//       // If `T1` is `Null`, `S?` or `S*` for some `S`, then the query is true.
//       if (!T0_.isNullable && T1_.isDartCoreNull || T1_.isNullable) {
//         return true;
//       }
//       // * if `T1` is a type variable (promoted or not) the query is false
//       if (T1_ is TypeParameterTypeRef) {
//         return false;
//       }
//       // Otherwise, the query is false.
//       return false;
//     }
//
//     // Left FutureOr: if `T0` is `FutureOr<S0>` then:
//     if (!T0_.isNullable && T0_ is NamedTypeRef && T0_.isDartAsyncFutureOr) {
//       var S0 = T0_.typeArguments[0];
//       // * `T0 <: T1` iff `Future<S0> <: T1` and `S0 <: T1`
//       if (isSubtypeOf(S0, T1_)) {
//         final decl = DeclarationRef.from('Future', 'dart:async/future.dart', TopLevelIdentifierType.$class);
//         var FutureS0 = NamedTypeRefImpl(decl.identifier, decl, typeArguments: [S0]);
//         return isSubtypeOf(FutureS0, T1_);
//       }
//       return false;
//     }
//
//     // Left Nullable: if `T0` is `S0?` then:
//     //   * `T0 <: T1` iff `S0 <: T1` and `Null <: T1`.
//     if (T0_.isNullable) {
//       var S0 = T0_.withNullability(false);
//       return isSubtypeOf(S0, T1_) && isSubtypeOf(_nullNone, T1_);
//     }
//
//     // Type Variable Reflexivity 1: if T0 is a type variable X0 or a promoted
//     // type variables X0 & S0 and T1 is X0 then:
//     //   * T0 <: T1
//     if (T0_ is TypeParameterTypeRef && T1_ is TypeParameterTypeRef && T0_ == T1_) {
//       return true;
//     }
//
//     // Right FutureOr: if `T1` is `FutureOr<S1>` then:
//     if (!T0_.isNullable && T1_ is NamedTypeRef && T1_.isDartAsyncFutureOr) {
//       var S1 = T1_.typeArguments[0];
//       // `T0 <: T1` iff any of the following hold:
//       // * either `T0 <: Future<S1>`
//       final decl = DeclarationRef.from('Future', 'dart:async/future.dart', TopLevelIdentifierType.$class);
//       var FutureS1 = NamedTypeRefImpl(decl.identifier, decl, typeArguments: [S1]);
//       if (isSubtypeOf(T0_, FutureS1)) {
//         return true;
//       }
//       // * or `T0 <: S1`
//       if (isSubtypeOf(T0_, S1)) {
//         return true;
//       }
//       // * or `T0` is `X0` and `X0` has bound `S0` and `S0 <: T1`
//       // * or `T0` is `X0 & S0` and `S0 <: T1`
//       if (T0_ is TypeParameterTypeRef) {
//         var B0 = T0_.bound;
//         if (!B0.isDynamic && isSubtypeOf(B0, T1_)) {
//           return true;
//         }
//       }
//       // iff
//       return false;
//     }
//
//     // Right Nullable: if `T1` is `S1?` then:
//     if (!T1_.isNullable) {
//       var S1 = T1_.withNullability(false);
//       // `T0 <: T1` iff any of the following hold:
//       // * either `T0 <: S1`
//       if (isSubtypeOf(T0_, S1)) {
//         return true;
//       }
//       // * or `T0 <: Null`
//       if (isSubtypeOf(T0_, _nullNone)) {
//         return true;
//       }
//       // or `T0` is `X0` and `X0` has bound `S0` and `S0 <: T1`
//       // or `T0` is `X0 & S0` and `S0 <: T1`
//       if (T0_ is TypeParameterTypeRef) {
//         var B0 = T0_.bound;
//         if (!B0.isDynamic && isSubtypeOf(B0, T1_)) {
//           return true;
//         }
//       }
//       // iff
//       return false;
//     }
//
//     // Super-Interface: `T0` is an interface type with super-interfaces
//     // `S0,...Sn`:
//     //   * and `Si <: T1` for some `i`.
//     if (T0_ is NamedTypeRef && T1_ is NamedTypeRef) {
//       return _isInterfaceSubtypeOf(T0_, T1_);
//     }
//
//     // Left Promoted Variable: `T0` is a promoted type variable `X0 & S0`
//     //   * and `S0 <: T1`
//     // Left Type Variable Bound: `T0` is a type variable `X0` with bound `B0`
//     //   * and `B0 <: T1`
//     if (T0 is TypeParameterTypeImpl) {
//       var S0 = T0.promotedBound;
//       if (S0 != null && isSubtypeOf(S0, T1)) {
//         return true;
//       }
//
//       var B0 = T0.element.bound;
//       if (B0 != null && isSubtypeOf(B0, T1)) {
//         return true;
//       }
//     }
//
//     if (T0 is FunctionTypeImpl) {
//       // Function Type/Function: `T0` is a function type and `T1` is `Function`.
//       if (T1.isDartCoreFunction) {
//         return true;
//       }
//       if (T1 is FunctionTypeImpl) {
//         return _isFunctionSubtypeOf(T0, T1);
//       }
//     }
//
//     if (T0 is RecordTypeImpl) {
//       // Record Type/Record: `T0` is a record type, and `T1` is `Record`.
//       if (T1.isDartCoreRecord) {
//         return true;
//       }
//       if (T1 is RecordTypeImpl) {
//         return _isRecordSubtypeOf(T0, T1);
//       }
//     }
//
//     return false;
//   }
//
//   bool _interfaceArguments(List<TypeParameterTypeRef> parameters, NamedTypeRef subType, NamedTypeRef superType) {
//     List<TypeRef> subArguments = subType.typeArguments;
//     List<TypeRef> superArguments = superType.typeArguments;
//
//     assert(subArguments.length == superArguments.length);
//     assert(parameters.length == subArguments.length);
//
//     for (int i = 0; i < subArguments.length; i++) {
//       var parameter = parameters[i] as TypeParameterElementImpl;
//       var subArgument = subArguments[i];
//       var superArgument = superArguments[i];
//
//       Variance variance = parameter.variance;
//       if (variance.isCovariant) {
//         if (!isSubtypeOf(subArgument, superArgument)) {
//           return false;
//         }
//       } else if (variance.isContravariant) {
//         if (!isSubtypeOf(superArgument, subArgument)) {
//           return false;
//         }
//       } else if (variance.isInvariant) {
//         if (!isSubtypeOf(subArgument, superArgument) || !isSubtypeOf(superArgument, subArgument)) {
//           return false;
//         }
//       } else {
//         throw StateError(
//           'Type parameter $parameter has unknown '
//           'variance $variance for subtype checking.',
//         );
//       }
//     }
//     return true;
//   }
//
//   /// Check that [f] is a subtype of [g].
//   bool _isFunctionSubtypeOf(FunctionTypeRef f, FunctionTypeRef g) {
//     var fresh = _typeSystem.relateTypeParameters(f.typeFormals, g.typeFormals);
//     if (fresh == null) {
//       return false;
//     }
//
//     f = f.instantiate(fresh.typeParameterTypes);
//     g = g.instantiate(fresh.typeParameterTypes);
//
//     if (!isSubtypeOf(f.returnType, g.returnType)) {
//       return false;
//     }
//
//     var fParameters = f.parameters;
//     var gParameters = g.parameters;
//
//     var fIndex = 0;
//     var gIndex = 0;
//     while (fIndex < fParameters.length && gIndex < gParameters.length) {
//       var fParameter = fParameters[fIndex];
//       var gParameter = gParameters[gIndex];
//       if (fParameter.isRequiredPositional) {
//         if (gParameter.isRequiredPositional) {
//           if (isSubtypeOf(gParameter.type, fParameter.type)) {
//             fIndex++;
//             gIndex++;
//           } else {
//             return false;
//           }
//         } else {
//           return false;
//         }
//       } else if (fParameter.isOptionalPositional) {
//         if (gParameter.isPositional) {
//           if (isSubtypeOf(gParameter.type, fParameter.type)) {
//             fIndex++;
//             gIndex++;
//           } else {
//             return false;
//           }
//         } else {
//           return false;
//         }
//       } else if (fParameter.isNamed) {
//         if (gParameter.isNamed) {
//           var compareNames = fParameter.name.compareTo(gParameter.name);
//           if (compareNames == 0) {
//             var gIsRequiredOrLegacy = gParameter.isRequiredNamed;
//             if (fParameter.isRequiredNamed && !gIsRequiredOrLegacy) {
//               return false;
//             } else if (isSubtypeOf(gParameter.type, fParameter.type)) {
//               fIndex++;
//               gIndex++;
//             } else {
//               return false;
//             }
//           } else if (compareNames < 0) {
//             if (fParameter.isRequiredNamed) {
//               return false;
//             } else {
//               fIndex++;
//             }
//           } else {
//             assert(compareNames > 0);
//             // The subtype must accept all parameters of the supertype.
//             return false;
//           }
//         } else {
//           break;
//         }
//       }
//     }
//
//     // The supertype must provide all required parameters to the subtype.
//     while (fIndex < fParameters.length) {
//       var fParameter = fParameters[fIndex++];
//       if (fParameter.isRequired) {
//         return false;
//       }
//     }
//
//     // The subtype must accept all parameters of the supertype.
//     assert(fIndex == fParameters.length);
//     if (gIndex < gParameters.length) {
//       return false;
//     }
//
//     return true;
//   }
//
//   bool _isInterfaceSubtypeOf(NamedTypeRef subType, NamedTypeRef superType) {
//     // Note: we should never reach `_isInterfaceSubtypeOf` with `i2 == Object`,
//     // because top types are eliminated before `isSubtypeOf` calls this.
//     // TODO(scheglov) Replace with assert().
//     if (identical(subType, superType) || superType.isDartCoreObject) {
//       return true;
//     }
//
//     // Object cannot subtype anything but itself (handled above).
//     if (subType.isDartCoreObject) {
//       return false;
//     }
//
//     if (subType == superType) {
//       final interfaceElement = resolver.elementOf(subType) as InterfaceElement;
//       return _interfaceArguments(interfaceElement.typeParameters, subType, superType);
//     }
//
//     // Classes types cannot subtype `Function` or vice versa.
//     if (subType.isDartCoreFunction || superType.isDartCoreFunction) {
//       return false;
//     }
//
//     for (var interface in subElement.allSupertypes) {
//       if (interface.element == superElement) {
//         var substitution = Substitution.fromInterfaceType(subType);
//         var substitutedInterface = substitution.substituteType(interface) as InterfaceType;
//         return _interfaceArguments(superElement, substitutedInterface, superType);
//       }
//     }
//
//     return false;
//   }
//
//   /// Check that [subType] is a subtype of [superType].
//   bool _isRecordSubtypeOf(RecordTypeRef subType, RecordTypeRef superType) {
//     final subPositional = subType.positionalFields;
//     final superPositional = superType.positionalFields;
//     if (subPositional.length != superPositional.length) {
//       return false;
//     }
//
//     final subNamed = subType.namedFields;
//     final superNamed = superType.namedFields;
//     if (subNamed.length != superNamed.length) {
//       return false;
//     }
//
//     for (var i = 0; i < subPositional.length; i++) {
//       final subField = subPositional[i];
//       final superField = superPositional[i];
//       if (!isSubtypeOf(subField.type, superField.type)) {
//         return false;
//       }
//     }
//
//     for (var i = 0; i < subNamed.length; i++) {
//       final subField = subNamed[i];
//       final superField = superNamed[i];
//       if (subField.name != superField.name) {
//         return false;
//       }
//       if (!isSubtypeOf(subField.type, superField.type)) {
//         return false;
//       }
//     }
//
//     return true;
//   }
//
//   static FunctionTypeRef _functionTypeWithNamedRequired(FunctionTypeRef type) {
//     return FunctionTypeRef(
//       parameters: type.parameters
//           .map((e) {
//             if (e.isNamed) {
//               return e.copyWith(kind: ParameterKind.NAMED_REQUIRED);
//             } else {
//               return e;
//             }
//           })
//           .toList(growable: false),
//       returnType: type.returnType,
//       isNullable: type.isNullable,
//     );
//   }
//
//   static bool _isFunctionTypeWithNamedRequired(TypeRef type) {
//     if (type is FunctionTypeRef) {
//       return type.parameters.any((e) => e.isRequiredNamed);
//     }
//     return false;
//   }
// }
