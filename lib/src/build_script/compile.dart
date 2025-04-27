import 'dart:io';

import 'errors.dart';
import 'files.dart';

void compileScript(String scriptPath) {
  final execPath = getExecutablePath();
  final result = Process.runSync('dart', ['compile', 'aot-snapshot', scriptPath, '-o', execPath]);
  if (!Platform.isWindows) {
    Process.runSync('chmod', ['+x', execPath]);
  }
  if (result.exitCode != 0) {
    throw CompileError('Failed to compile the script: ${result.stderr}');
  }
}

String getExecutablePath() {
  if (Platform.isWindows) {
    return '$scriptExecutable.exe';
  } else {
    return scriptExecutable;
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
