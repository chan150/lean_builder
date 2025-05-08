/// Base class for all resolver-related errors.
///
/// This exception is thrown when the resolver encounters issues with
/// finding, parsing, or resolving Dart files and their dependencies.
abstract class PackageFileResolverError implements Exception {}

/// Package configuration could not be loaded.
///
/// This error occurs when the package_config.json file is missing,
/// usually indicating that dependencies haven't been fetched.
class PackageConfigNotFound extends PackageFileResolverError {
  /// Creates a new [PackageConfigNotFound] error.
  PackageConfigNotFound();

  @override
  String toString() =>
      'Could not find package_config.json file\ntry running `flutter pub get` or `pub get` then re-run the build';
}

/// JSON parsing failed when processing package configuration.
///
/// This occurs when the package_config.json file exists but contains
/// invalid JSON or doesn't match the expected format.
class PackageConfigParseError extends PackageFileResolverError {
  /// The source content that failed to parse.
  final String source;

  /// The underlying error that caused the parsing failure, if available.
  final Object? cause;

  /// Creates a new [PackageConfigParseError] with the given source and optional cause.
  PackageConfigParseError(this.source, [this.cause]);

  @override
  String toString() =>
      'PackageConfigParseError: Invalid package configuration format${cause != null ? ', cause: $cause' : ''}';
}

/// Requested package not found in configuration.
///
/// This error is thrown when attempting to resolve a package that isn't
/// listed in the package configuration.
class PackageNotFoundError extends PackageFileResolverError {
  /// Detailed message explaining which package was not found.
  final String message;

  /// Creates a new [PackageNotFoundError] with the given message.
  PackageNotFoundError(this.message);

  @override
  String toString() => message;
}

/// Asset URI could not be constructed.
///
/// This occurs when an asset path cannot be converted to a valid URI,
/// usually due to invalid path formats or missing package information.
class AssetUriError extends PackageFileResolverError {
  /// The path that couldn't be converted to an asset URI.
  final String path;

  /// Optional explanation for why the URI couldn't be constructed.
  final String? reason;

  /// Creates a new [AssetUriError] for the given path with an optional reason.
  AssetUriError(this.path, [this.reason]);

  @override
  String toString() =>
      'AssetUriError: Unable to build asset URI for "$path"${reason != null ? ', reason: $reason' : ''}';
}

/// Invalid path format or structure.
///
/// This error is thrown when a file path doesn't follow the expected format
/// or points to a location that cannot exist in the project structure.
class InvalidPathError extends PackageFileResolverError {
  /// The invalid path that caused the error.
  final String path;

  /// Creates a new [InvalidPathError] for the given path.
  InvalidPathError(this.path);

  @override
  String toString() => 'InvalidPathError: Path "$path" is invalid';
}
