// import 'package:code_genie/src/resolvers/element/element.dart';
// import 'package:code_genie/src/resolvers/type/type.dart';
// import 'package:code_genie/src/resolvers/type/type_ref.dart';
//
// class Substitution {
//   final Map<TypeParameterElement, DartType> _map;
//
//   Substitution(this._map);
//
//   /// Creates a substitution that maps the given type parameters to the
//   /// corresponding type arguments.
//   factory Substitution.fromPairs(List<TypeParameterElement> typeParameters, List<TypeRef> typeArguments) {
//     assert(typeParameters.length == typeArguments.length);
//     final map = <TypeParameterElement, TypeRef>{};
//     for (var i = 0; i < typeParameters.length; i++) {
//       map[typeParameters[i]] = typeArguments[i];
//     }
//     return Substitution(map);
//   }
//
//   /// Applies this substitution to the given [type].
//   DartType substituteType(TypeRef type) {
//     if (type is TypeParameterType) {
//       return _map[type.element] ?? type;
//     } else if (type is InterfaceType) {
//       if (type.typeArguments.isEmpty) {
//         return type;
//       }
//       final substitutedTypeArgs = type.typeArguments.map((typeArg) => substituteType(typeArg)).toList();
//       return InterfaceTypeImpl(
//         type.element,
//         typeArguments: substitutedTypeArgs,
//         alias: type.alias,
//         isNullable: type.isNullable,
//       );
//     } else if (type is FunctionType) {
//       // final returnType = substituteType(type.returnType);
//       // final parameters =
//       //     type.parameters.map((param) {
//       //       if (param is ParameterElementImpl) {
//       //         param.type = substituteType(param.type);
//       //       }
//       //       return param;
//       //     }).toList();
//       // return FunctionTypeImpl(
//       //   name: type.name,
//       //   returnType: returnType,
//       //   typeParameters: type.typeParameters,
//       //   parameters: parameters,
//       //   isNullable: type.isNullable,
//       // );
//     }
//     return type;
//   }
// }
