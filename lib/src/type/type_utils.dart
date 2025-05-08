import 'package:lean_builder/element.dart';
import 'package:lean_builder/src/graph/declaration_ref.dart';
import 'package:lean_builder/src/graph/scan_results.dart';
import 'package:lean_builder/src/resolvers/resolver.dart';
import 'package:lean_builder/src/type/core_type_source.dart';
import 'package:lean_builder/src/type/substitution.dart';
import 'package:lean_builder/src/type/subtype.dart';
import 'package:lean_builder/src/type/type.dart';

/// {@template type_utils}
/// Utility class for working with Dart types at build time.
///
/// Provides methods for type comparison, checking subtype relationships,
/// and creating commonly used types.
/// {@endtemplate}
class TypeUtils {
  /// The resolver to use for type-related operations.
  final ResolverImpl resolver;

  /// Helper for checking subtype relationships.
  late final SubtypeHelper _subtypeHelper = SubtypeHelper(this);

  /// Whether to enforce strict casting rules.
  ///
  /// When true, implicit downcasts are not allowed.
  final bool strictCasts;

  /// Creates a [TypeUtils] instance with the specified resolver and strictness settings.
  TypeUtils(this.resolver, {this.strictCasts = false});

  /// {@template core_type_getter}
  /// Returns an [InterfaceType] instance representing the {TYPE} type.
  /// {@endtemplate}

  /// {@macro core_type_getter}
  InterfaceType get objectType {
    final DeclarationRef declarationRef = DeclarationRef.from(
      'Object',
      CoreTypeSource.coreObject,
      ReferenceType.$class,
    );
    return InterfaceTypeImpl('Object', declarationRef, resolver);
  }

  /// {@macro core_type_getter}
  ///
  /// This returns a nullable version of the Object type.
  InterfaceType get objectTypeNullable {
    final DeclarationRef declarationRef = DeclarationRef.from(
      'Object',
      CoreTypeSource.coreObject,
      ReferenceType.$class,
    );
    return InterfaceTypeImpl('Object?', declarationRef, resolver, isNullable: true);
  }

  /// {@macro core_type_getter}
  InterfaceType get nullTypeObject {
    final DeclarationRef declarationRef = DeclarationRef.from('Null', CoreTypeSource.coreNull, ReferenceType.$class);
    return InterfaceTypeImpl('Null', declarationRef, resolver);
  }

  /// Builds a [Future&lt;T&gt;] type with the specified type parameter.
  ///
  /// [typeParam] is the type argument for the Future.
  /// [isNullable] specifies whether the Future type itself is nullable.
  InterfaceType buildFutureType(DartType typeParam, {bool isNullable = false}) {
    final DeclarationRef declarationRef = DeclarationRef.from(
      'Future',
      CoreTypeSource.asyncFuture,
      ReferenceType.$class,
    );
    return InterfaceTypeImpl(
      'Future',
      declarationRef,
      resolver,
      typeArguments: <DartType>[typeParam],
      isNullable: isNullable,
    );
  }

  /// Determines if a type is nullable according to Dart's type system.
  ///
  /// A type is nullable if:
  /// - It's explicitly marked as nullable
  /// - It's a special type like dynamic, void, or invalid
  /// - It's the Null type
  /// - It's a FutureOr&lt;T&gt; where T is nullable
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

  /// Relates two lists of type parameters to determine if they're compatible.
  ///
  /// Given two lists of type parameters, checks that they have the same
  /// number of elements, and their bounds are equal.
  ///
  /// Returns a [RelatedTypeParameters] instance with fresh type parameters that can
  /// be used to instantiate both function types, or null if the parameters are incompatible.
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

    int length = typeParameters1.length;
    List<TypeParameterType> freshTypeParameters = List<TypeParameterType>.generate(length, (int index) {
      return typeParameters1[index];
    }, growable: false);

    List<TypeParameterType> freshTypeParameterTypes = List<TypeParameterType>.generate(length, (int index) {
      return freshTypeParameters[index];
    }, growable: false);

    Substitution substitution1 = Substitution.fromPairs(typeParameters1, freshTypeParameterTypes);
    Substitution substitution2 = Substitution.fromPairs(typeParameters2, freshTypeParameterTypes);

    for (int i = 0; i < typeParameters1.length; i++) {
      DartType bound1 = typeParameters1[i].bound;
      DartType bound2 = typeParameters2[i].bound;

      bound1 = substitution1.substituteType(bound1);
      bound2 = substitution2.substituteType(bound2);
      if (!isEqualTo(bound1, bound2)) {
        return null;
      }

      if (bound1 is! DynamicType) {
        final TypeParameterType old = freshTypeParameters[i];
        freshTypeParameters[i] = TypeParameterType(old.name, bound: bound1, isNullable: old.isNullable);
      }
    }

    return RelatedTypeParameters._(freshTypeParameters, freshTypeParameterTypes);
  }

  /// Checks if two types are exactly equal.
  ///
  /// Types are equal if they are subtypes of each other.
  bool isEqualTo(DartType left, DartType right) {
    return isSubtypeOf(left, right) && isSubtypeOf(right, left);
  }

  /// Checks if [leftType] is a subtype of [rightType].
  ///
  /// Uses the subtype helper to determine the relationship.
  bool isSubtypeOf(DartType leftType, DartType rightType) {
    return _subtypeHelper.isSubtypeOf(leftType, rightType);
  }

  /// Determines if [fromType] can be assigned to [toType].
  ///
  /// This checks for subtype relationships and also handles special cases
  /// like implicit downcasts (when [strictCasts] is false) and function type compatibility.
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
      FunctionType? callMethodType = getCallMethodType(fromType);
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

  /// Determines if a type accepts a function type.
  ///
  /// A type accepts a function type if:
  /// - It is a function type
  /// - It is the Function class from dart:core
  /// - It is FutureOr&lt;T&gt; where T accepts a function type
  bool acceptsFunctionType(DartType? t) {
    if (t == null) return false;
    if (t.isDartAsyncFutureOr) {
      return acceptsFunctionType((t as InterfaceType).typeArguments[0]);
    }
    return t is FunctionType || t.isDartCoreFunction;
  }

  /// Retrieves the function type of the 'call' method on a type, if it exists.
  ///
  /// This is used to handle callable classes that define a call method.
  /// Returns null if the type doesn't have a call method.
  FunctionType? getCallMethodType(DartType t) {
    if (t is InterfaceType) {
      final InterfaceElement interfaceElement = t.element;
      return interfaceElement.getMethod(FunctionElement.kCALLMethodName)?.type;
    }
    return null;
  }
}

/// {@template related_type_parameters}
/// Represents a relationship between two sets of type parameters.
///
/// This class holds fresh type parameters that are compatible with two
/// different sets of type parameters, allowing for further comparison.
/// {@endtemplate}
class RelatedTypeParameters {
  /// An empty instance for when there are no type parameters.
  static final RelatedTypeParameters _empty = RelatedTypeParameters._(
    const <TypeParameterType>[],
    const <TypeParameterType>[],
  );

  /// Fresh type parameters that can be used in place of the original ones.
  final List<TypeParameterType> typeParameters;

  /// Types corresponding to the fresh type parameters.
  final List<TypeParameterType> typeParameterTypes;

  /// Creates a new [RelatedTypeParameters] instance.
  RelatedTypeParameters._(this.typeParameters, this.typeParameterTypes);
}
