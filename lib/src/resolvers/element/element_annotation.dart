part of 'element.dart';

const String _metaPackageUri = 'package:meta/meta.dart';
const String _metaMetaPackageUri = 'package:meta/meta_meta.dart';
const String _coreAnnotationsUri = 'dart:core/annotations.dart';

abstract class ElementAnnotation {
  String get name;

  Constant get constant;

  TypeRef get type;

  DeclarationRef get declarationRef;

  /// Whether the annotation marks the associated function as always throwing.
  bool get isAlwaysThrows;

  /// Whether the annotation marks the associated element as being deprecated.
  bool get isDeprecated;

  /// Whether the annotation marks the associated element as not to be stored.
  bool get isDoNotStore;

  /// Whether the annotation marks the associated member as a factory.
  bool get isFactory;

  /// Whether the annotation marks the associated class and its subclasses as
  /// being immutable.
  bool get isImmutable;

  /// Whether the annotation marks the associated element as being internal to
  /// its package.
  bool get isInternal;

  /// Whether the annotation marks the associated member as running a single
  /// test.
  bool get isIsTest;

  /// Whether the annotation marks the associated member as running a test
  /// group.
  bool get isIsTestGroup;

  /// Whether the annotation marks the associated constructor as being literal.
  bool get isLiteral;

  /// Whether the annotation marks the associated member as requiring
  /// subclasses to override this member.
  bool get isMustBeOverridden;

  /// Whether the annotation marks the associated member as requiring
  /// overriding methods to call super.
  bool get isMustCallSuper;

  /// Whether the annotation marks the associated member as being non-virtual.
  bool get isNonVirtual;

  /// Whether the annotation marks the associated type as having "optional"
  /// type arguments.
  bool get isOptionalTypeArgs;

  /// Whether the annotation marks the associated method as being expected to
  /// override an inherited method.
  bool get isOverride;

  /// Whether the annotation marks the associated member as being protected.
  bool get isProtected;

  /// Whether the annotation marks the associated member as re-declaring.
  bool get isRedeclare;

  /// Whether the annotation marks the associated member as being reopened.
  bool get isReopen;

  /// Whether the annotation marks the associated member as being required.
  bool get isRequired;

  /// Whether the annotation marks the associated class as being sealed.
  bool get isSealed;

  /// Whether the annotation marks the associated class as being intended to
  /// be used as an annotation.
  bool get isTarget;

  /// Whether the annotation marks the associated returned element as
  /// requiring use.
  bool get isUseResult;

  /// Whether the annotation marks the associated member as being visible for
  /// overriding only.
  bool get isVisibleForOverriding;
}

class ElementAnnotationImpl implements ElementAnnotation {
  @override
  final TypeRef type;

  @override
  final DeclarationRef declarationRef;

  @override
  Constant get constant => _constValue ??= _constantValueCompute() ?? Constant.invalid;

  Constant? _constValue;

  final ConstantValueCompute _constantValueCompute;

  @override
  String get name => declarationRef.identifier;

  ElementAnnotationImpl({
    required this.type,
    required ConstantValueCompute constantValueCompute,
    required this.declarationRef,
  }) : _constantValueCompute = constantValueCompute;

  late final String _srcName = declarationRef.srcUri.toString();

  bool _isMeta(String name) => _belongsToPackage(_metaPackageUri, name);

  bool _isCore(String name) => _belongsToPackage(_coreAnnotationsUri, name);

  bool _belongsToPackage(String srcName, String name) {
    return _srcName == srcName && name == this.name;
  }

  @override
  bool get isAlwaysThrows => _isMeta('alwaysThrows');

  @override
  bool get isDeprecated => _isCore('deprecated') || _isCore('Deprecated');

  @override
  bool get isDoNotStore => _isMeta('doNotStore');

  @override
  bool get isFactory => _isMeta('factory');

  @override
  bool get isInternal => _isMeta('internal');

  @override
  bool get isIsTest => _isMeta('isTest');

  @override
  bool get isIsTestGroup => _isMeta('isTestGroup');

  @override
  bool get isLiteral => _isMeta('literal');

  @override
  bool get isMustBeOverridden => _isMeta('mustBeOverridden');

  @override
  bool get isMustCallSuper => _isMeta('mustCallSuper');

  @override
  bool get isNonVirtual => _isMeta('nonVirtual');

  @override
  bool get isOptionalTypeArgs => _isMeta('optionalTypeArgs');

  @override
  bool get isOverride => _isCore('override');

  @override
  bool get isProtected => _isMeta('protected');

  @override
  bool get isRedeclare => _isMeta('redeclare');

  @override
  bool get isReopen => _isMeta('reopen');

  @override
  bool get isRequired => _isMeta('required');

  @override
  bool get isSealed => _isMeta('sealed');

  @override
  bool get isUseResult => _isMeta('useResult') || _isMeta('UseResult');

  @override
  bool get isVisibleForOverriding => _isMeta('visibleForOverriding');

  @override
  bool get isImmutable => _isMeta('immutable');

  @override
  bool get isTarget {
    return _belongsToPackage(_metaMetaPackageUri, 'Target');
  }

  @override
  String toString() {
    return '@$name';
  }
}
