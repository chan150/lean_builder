/// Base error class for all build script errors
abstract class BuildScriptError implements Exception {
  String get message;

  @override
  String toString() => message;
}

/// Error thrown when the build configuration is invalid
class BuildConfigError extends BuildScriptError {
  final String _message;

  BuildConfigError(this._message);

  @override
  String get message => 'Build configuration error\n$_message.';
}

/// Error thrown when a file operation fails during build
class BuildFileError extends BuildScriptError {
  final String filePath;
  final String operation;
  final Object? cause;

  BuildFileError(this.filePath, this.operation, {this.cause});

  @override
  String get message =>
      'File operation "$operation" failed for "$filePath"'
      '${cause != null ? ": $cause" : "."}';
}

/// Compile error
class CompileError extends BuildScriptError {
  final String _message;

  CompileError(this._message);

  @override
  String get message => 'Compile error\n$_message.';
}
