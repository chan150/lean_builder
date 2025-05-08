/// Base class for all resolver-related errors.
///
/// This exception is thrown when the resolver encounters issues with
/// finding, parsing, or resolving Dart files and their dependencies.
abstract class ResolverError implements Exception {}

/// Identifier not found in scope.
///
/// This error occurs when trying to resolve a symbol or identifier that
/// doesn't exist in the current scope or imported libraries.
class IdentifierNotFoundError extends ResolverError {
  /// The identifier that couldn't be resolved.
  final String identifier;

  /// The import prefix, if any (e.g., "dart" in "dart:core").
  final String? importPrefix;

  /// The library where the resolution was attempted.
  final Uri importingLibrary;

  /// Creates a new [IdentifierNotFoundError] with the given details.
  IdentifierNotFoundError(
    this.identifier,
    this.importPrefix,
    this.importingLibrary,
  );

  @override
  String toString() =>
      'Could not resolve "${importPrefix == null ? '' : '$importPrefix.'}$identifier" in $importingLibrary';
}
