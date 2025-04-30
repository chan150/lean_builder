abstract class ResolverError implements Exception {}

/// Package configuration could not be loaded
class PackageConfigNotFound extends ResolverError {
  PackageConfigNotFound();

  @override
  String toString() =>
      'Could not find package_config.json file\ntry running `flutter pub get` or `pub get` then re-run the build';
}

/// JSON parsing failed when processing package configuration
class PackageConfigParseError extends ResolverError {
  final String source;
  final Object? cause;

  PackageConfigParseError(this.source, [this.cause]);

  @override
  String toString() =>
      'PackageConfigParseError: Invalid package configuration format${cause != null ? ', cause: $cause' : ''}';
}

/// Requested package not found in configuration
class PackageNotFoundError extends ResolverError {
  final String package;

  PackageNotFoundError(this.package);

  @override
  String toString() => 'PackageNotFoundError: Package "$package" not found';
}

/// Asset URI could not be constructed
class AssetUriError extends ResolverError {
  final String path;
  final String? reason;

  AssetUriError(this.path, [this.reason]);

  @override
  String toString() =>
      'AssetUriError: Unable to build asset URI for "$path"${reason != null ? ', reason: $reason' : ''}';
}

/// Invalid path format or structure
class InvalidPathError extends ResolverError {
  final String path;

  InvalidPathError(this.path);

  @override
  String toString() => 'InvalidPathError: Path "$path" is invalid';
}

/// identifier not found
class IdentifierNotFoundError extends ResolverError {
  final String identifier;
  final String? importPrefix;
  final Uri importingLibrary;

  IdentifierNotFoundError(this.identifier, this.importPrefix, this.importingLibrary);

  @override
  String toString() =>
      'Could not resolve "${importPrefix == null ? '' : '$importPrefix.'}$identifier" in $importingLibrary';
}
