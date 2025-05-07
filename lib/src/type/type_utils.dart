import 'package:lean_builder/element.dart';
import 'package:lean_builder/src/graph/identifier_ref.dart';
import 'package:lean_builder/src/graph/scan_results.dart';
import 'package:lean_builder/src/resolvers/resolver.dart';
import 'package:lean_builder/src/type/core_type_source.dart';
import 'package:lean_builder/src/type/substitution.dart';
import 'package:lean_builder/src/type/subtype.dart';
import 'package:lean_builder/src/type/type.dart';

class TypeUtils {
  final ResolverImpl resolver;
  late final _subtypeHelper = SubtypeHelper(this);
  final bool strictCasts;
  TypeUtils(this.resolver, {this.strictCasts = false});

  InterfaceType get objectType {
    final declarationRef = DeclarationRef.from('Object', CoreTypeSource.coreObject, SymbolType.$class);
    return InterfaceTypeImpl('Object', declarationRef, resolver);
  }

  InterfaceType get objectTypeNullable {
    final declarationRef = DeclarationRef.from('Object', CoreTypeSource.coreObject, SymbolType.$class);
    return InterfaceTypeImpl('Object?', declarationRef, resolver, isNullable: true);
  }

  InterfaceType get nullTypeObject {
    final declarationRef = DeclarationRef.from('Null', CoreTypeSource.coreNull, SymbolType.$class);
    return InterfaceTypeImpl('Null', declarationRef, resolver);
  }

  InterfaceType buildFutureType(DartType typeParam, {bool isNullable = false}) {
    final declarationRef = DeclarationRef.from('Future', CoreTypeSource.asyncFuture, SymbolType.$class);
    return InterfaceTypeImpl('Future', declarationRef, resolver, typeArguments: [typeParam], isNullable: false);
  }

  bool isNullable(DartType type) {
    if (type is DynamicType ||
        type is InvalidType ||
        type is UnknownInferredType ||
        type is VoidType ||
        type.isDartCoreNull) {
      return true;
    } else if (type is TypeParameterType && type.promotedBound != null) {
      return isNullable(type.promotedBound!);
    } else if (type.isNullable) {
      return true;
    } else if (type is InterfaceTypeImpl) {
      if (type.isDartAsyncFutureOr) {
        return isNullable(type.typeArguments[0]);
      }
    }
    return false;
  }

  /// Given two lists of type parameters, check that they have the same
  /// number of elements, and their bounds are equal.
  ///
  /// The return value will be a new list of fresh type parameters, that can
  /// be used to instantiate both function types, allowing further comparison.
  RelatedTypeParameters? relateTypeParameters(
    List<TypeParameterType> typeParameters1,
    List<TypeParameterType> typeParameters2,
  ) {
    if (typeParameters1.length != typeParameters2.length) {
      return null;
    }
    if (typeParameters1.isEmpty) {
      return RelatedTypeParameters._empty;
    }

    var length = typeParameters1.length;
    var freshTypeParameters = List.generate(length, (index) {
      return typeParameters1[index];
    }, growable: false);

    var freshTypeParameterTypes = List.generate(length, (index) {
      return freshTypeParameters[index];
    }, growable: false);

    var substitution1 = Substitution.fromPairs(typeParameters1, freshTypeParameterTypes);
    var substitution2 = Substitution.fromPairs(typeParameters2, freshTypeParameterTypes);

    for (var i = 0; i < typeParameters1.length; i++) {
      var bound1 = typeParameters1[i].bound;
      var bound2 = typeParameters2[i].bound;

      bound1 = substitution1.substituteType(bound1);
      bound2 = substitution2.substituteType(bound2);
      if (!isEqualTo(bound1, bound2)) {
        return null;
      }

      if (bound1 is! DynamicType) {
        final old = freshTypeParameters[i];
        freshTypeParameters[i] = TypeParameterType(old.name, bound: bound1, isNullable: old.isNullable);
      }
    }

    return RelatedTypeParameters._(freshTypeParameters, freshTypeParameterTypes);
  }

  bool isEqualTo(DartType left, DartType right) {
    return isSubtypeOf(left, right) && isSubtypeOf(right, left);
  }

  bool isSubtypeOf(DartType leftType, DartType rightType) {
    return _subtypeHelper.isSubtypeOf(leftType, rightType);
  }

  bool isAssignableTo(DartType fromType, DartType toType) {
    // An actual subtype
    if (isSubtypeOf(fromType, toType)) {
      return true;
    }

    // Accept the invalid type, we have already reported an error for it.
    if (fromType is InvalidType) {
      return true;
    }

    // A 'call' method tearoff.
    if (fromType is InterfaceType && !isNullable(fromType) && acceptsFunctionType(toType)) {
      var callMethodType = getCallMethodType(fromType);
      if (callMethodType != null && isAssignableTo(callMethodType, toType)) {
        return true;
      }
    }

    // First make sure that the static analysis option, `strict-casts: true`
    // disables all downcasts, including casts from `dynamic`.
    if (strictCasts) {
      return false;
    }

    // Don't allow implicit downcasts between function types
    // and call method objects, as these will almost always fail.
    if (fromType is FunctionType && getCallMethodType(toType) != null) {
      return false;
    }

    // Don't allow a non-generic function where a generic one is expected. The
    // former wouldn't know how to handle type arguments being passed to it.

    if (fromType is FunctionType &&
        toType is FunctionType &&
        fromType.typeParameters.isEmpty &&
        toType.typeParameters.isNotEmpty) {
      return false;
    }

    // If the subtype relation goes the other way, allow the implicit downcast.
    if (isSubtypeOf(toType, fromType)) {
      return true;
    }

    return false;
  }

  bool acceptsFunctionType(DartType? t) {
    if (t == null) return false;
    if (t.isDartAsyncFutureOr) {
      return acceptsFunctionType((t as InterfaceType).typeArguments[0]);
    }
    return t is FunctionType || t.isDartCoreFunction;
  }

  FunctionType? getCallMethodType(DartType t) {
    if (t is InterfaceType) {
      final interfaceElement = t.element;
      return interfaceElement.getMethod(FunctionElement.kCALLMethodName)?.type;
    }
    return null;
  }
}

class RelatedTypeParameters {
  static final _empty = RelatedTypeParameters._(const [], const []);

  final List<TypeParameterType> typeParameters;
  final List<TypeParameterType> typeParameterTypes;

  RelatedTypeParameters._(this.typeParameters, this.typeParameterTypes);
}
