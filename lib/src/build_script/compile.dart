import 'dart:io';

import 'errors.dart';
import 'files.dart';

void compileScript(String scriptPath) {
  final execPath = getExecutablePath();
  final result = Process.runSync('dart', ['compile', 'aot-snapshot', scriptPath]);
  if (!Platform.isWindows) {
    Process.runSync('chmod', ['+x', execPath]);
  }
  if (result.exitCode != 0) {
    throw CompileError('Failed to compile the script: ${result.stderr}');
  }
}

String getExecutablePath() {
  if (Platform.isWindows) {
    return '$scriptExecutable.aot';
  } else {
    return '$scriptExecutable.aot';
  }
}

bool executableExists() {
  return File(getExecutablePath()).existsSync();
}

void invalidateExecutable() {
  final executable = File(getExecutablePath());
  if (executable.existsSync()) {
    executable.deleteSync();
  }
}
