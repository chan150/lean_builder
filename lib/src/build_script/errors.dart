/// Base error class for all build script errors.
///
/// Provides a common interface for all errors that can occur during
/// the build process, allowing consistent error handling throughout
/// the application.
abstract class BuildScriptError implements Exception {
  /// Human-readable error message describing what went wrong.
  String get message;

  @override
  String toString() => message;
}

/// Error thrown when the build configuration is invalid.
///
/// This error indicates issues with the build configuration setup,
/// such as missing required fields, invalid values, or incompatible
/// settings that prevent the build from starting correctly.
class BuildConfigError extends BuildScriptError {
  final String _message;

  /// Creates a new build configuration error with the specified message.
  ///
  /// @param _message Detailed description of the configuration issue
  BuildConfigError(this._message);

  @override
  String get message => 'Build configuration error\n$_message.';
}

/// Error thrown when compilation of the build script fails.
///
/// This error occurs when the Dart compiler encounters issues
/// while transforming the build script into an executable snapshot.
class CompileError extends BuildScriptError {
  final String _message;

  /// Creates a new compilation error with the specified message.
  ///
  /// @param _message Detailed description of the compilation failure,
  ///                 typically containing compiler output
  CompileError(this._message);

  @override
  String get message => '$_message.';
}
