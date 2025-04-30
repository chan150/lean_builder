/// Represents the different kinds of variance a type parameter can have.
enum Variance {
  /// When a type parameter doesn't occur in a type.
  unrelated,

  /// When a type parameter allows a more derived type (subtype) to be used
  /// where a less derived type (supertype) is expected.
  ///
  /// Example: List&lt;Cat&gt; can be used where List&lt;Animal&gt; is expected
  /// if Cat is a subtype of Animal.
  covariant,

  /// When a type parameter allows a less derived type (supertype) to be used
  /// where a more derived type (subtype) is expected.
  ///
  /// Example: Function(Animal) can be used where Function(Cat) is expected
  /// if Cat is a subtype of Animal.
  contravariant,

  /// When a type parameter requires the exact type to be used.
  ///
  /// Example: Neither Set&lt;Cat&gt; nor Set&lt;Animal&gt; can be used in place of each other,
  /// even if Cat is a subtype of Animal.
  invariant;

  /// Whether this variance is covariant.
  bool get isCovariant => this == covariant;

  /// Whether this variance is contravariant.
  bool get isContravariant => this == contravariant;

  /// Whether this variance is invariant.
  bool get isInvariant => this == invariant;

  /// Whether this variance is unrelated.
  bool get isUnrelated => this == unrelated;

  /// Combines this variance with another variance.
  Variance combine(Variance other) {
    if (isUnrelated || other.isUnrelated) return unrelated;
    if (isInvariant || other.isInvariant) return invariant;
    return this == other ? covariant : contravariant;
  }

  /// Returns the meet of two variances in the variance lattice.
  Variance meet(Variance other) {
    if (isInvariant || other.isInvariant) return invariant;
    if (this == other) return this;
    if (isUnrelated) return other;
    if (other.isUnrelated) return this;
    return invariant;
  }

  /// Returns the string representation of this variance as a keyword.
  String toKeywordString() {
    switch (this) {
      case contravariant:
        return 'in';
      case invariant:
        return 'inout';
      case covariant:
        return 'out';
      case unrelated:
        return '';
    }
  }

  /// Creates a Variance from a keyword string.
  static Variance fromKeywordString(String str) {
    switch (str) {
      case 'in':
        return contravariant;
      case 'inout':
        return invariant;
      case 'out':
        return covariant;
      case '':
        return unrelated;
      default:
        throw ArgumentError('Invalid variance keyword: $str');
    }
  }
}
