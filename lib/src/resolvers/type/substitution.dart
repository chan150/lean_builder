import 'package:code_genie/src/resolvers/element/element.dart';
import 'package:code_genie/src/resolvers/type/type_ref.dart';

class Substitution {
  final Map<TypeParameterTypeRef, TypeRef> _map;

  Substitution(this._map);

  /// Creates a substitution that maps the given type parameters to the
  /// corresponding type arguments.
  factory Substitution.fromPairs(List<TypeParameterTypeRef> typeParameters, List<TypeRef> typeArguments) {
    assert(typeParameters.length == typeArguments.length);
    final map = <TypeParameterTypeRef, TypeRef>{};
    for (var i = 0; i < typeParameters.length; i++) {
      map[typeParameters[i]] = typeArguments[i];
    }
    return Substitution(map);
  }

  /// Applies this substitution to the given [type].
  TypeRef substituteType(TypeRef type, {bool isNullable = false}) {
    if (type is TypeParameterTypeRef) {
      return _map[type]?.withNullability(type.isNullable) ?? type;
    } else if (type is NamedTypeRef) {
      if (type.typeArguments.isEmpty) {
        return type;
      }
      final substitutedTypeArgs = type.typeArguments.map((typeArg) => substituteType(typeArg)).toList();
      return NamedTypeRef(
        type.name,
        type.src,
        typeArguments: substitutedTypeArgs,
        // alias: type.alias,
        isNullable: isNullable,
      );
    } else if (type is FunctionTypeRef) {
      final returnType = substituteType(type.returnType);
      final parameters =
          type.parameters.map((param) {
            if (param is ParameterElementImpl) {
              param.type = substituteType(param.type);
            }
            return param;
          }).toList();
      return FunctionTypeRef(
        type.name,
        returnType: returnType,
        typeParameters: type.typeParameters,
        parameters: parameters,
        isNullable: isNullable,
      );
    }
    return type;
  }
}
