import 'dart:io' show File, ProcessResult, Process, Platform;

import 'errors.dart';
import 'paths.dart' as paths;

/// Compiles the build script at the given path to an AOT snapshot.
///
/// Uses the Dart compiler to create an executable snapshot that can be
/// run more efficiently than interpreting the script each time.
/// Throws a [CompileError] if compilation fails.
///
/// @param scriptPath The path to the Dart script to be compiled
void compileScript(String scriptPath) {
  final String execPath = getExecutablePath();
  final ProcessResult result = Process.runSync('dart', <String>[
    'compile',
    'aot-snapshot',
    scriptPath,
  ]);
  if (!Platform.isWindows) {
    Process.runSync('chmod', <String>['+x', execPath]);
  }
  if (result.exitCode != 0) {
    throw CompileError('Failed to compile the script: ${result.stderr}');
  }
}

/// Returns the platform-specific path to the compiled executable.
///
/// The path is determined based on the current platform and the
/// global [scriptExecutable] configuration.
///
/// @return The path to the compiled executable
String getExecutablePath() {
  return '${paths.scriptExecutable}.aot';
}

/// Checks if the compiled executable exists on the file system.
///
/// @return `true` if the executable exists, `false` otherwise
bool executableExists() {
  return File(getExecutablePath()).existsSync();
}

/// Deletes the compiled executable if it exists.
///
/// Used to force recompilation when the script has been modified
/// or when the executable may be in an inconsistent state.
void invalidateExecutable() {
  final File executable = File(getExecutablePath());
  if (executable.existsSync()) {
    executable.deleteSync();
  }
}
