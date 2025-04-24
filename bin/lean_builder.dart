import 'dart:io';

import 'package:lean_builder/src/build_script/build_script.dart';
import 'package:lean_builder/src/build_script/compile.dart';
import 'package:lean_builder/src/logger.dart';
import 'package:args/args.dart';

void main(List<String> args) async {
  try {
    Logger.info('Starting Lean Builder...');
    final isDevMode = args.contains('--dev') || args.contains('-d');
    final scriptPath = prepareBuildScript();
    if (scriptPath == null) {
      Logger.info('No valid build script found. Exiting.');
      exit(0);
    }

    final int exitCode;
    if (isDevMode) {
      invalidateExecutable();
      exitCode = await _runJit(scriptPath, args);
    } else {
      exitCode = await _runAot(scriptPath, args);
    }
    if (exitCode != 0) {
      Logger.severe('Build failed with exit code: $exitCode');
    }
  } catch (e) {
    Logger.severe('Error preparing build script: $e');
    exit(1);
  }
}

Future<int> _runJit(String scriptPath, List<String> args) async {
  Logger.warning('Running in JIT mode. This may be slower than AOT.');
  return _runProcess('dart', ['run', scriptPath, ...args]);
}

Future<int> _runAot(String scriptPath, List<String> args) async {
  final executableFile = File(getExecutablePath());
  if (!executableFile.existsSync()) {
    compileScript(scriptPath);
  }
  final dartExecutable = Platform.resolvedExecutable;
  final dartSdkDir = Directory(dartExecutable).parent.path;
  return _runProcess('$dartSdkDir${Platform.pathSeparator}dartaotruntime', [executableFile.path, ...args]);
}

Future<int> _runProcess(String executable, List<String> arguments) async {
  final process = await Process.start(executable, arguments, mode: ProcessStartMode.inheritStdio);

  // Wait for the process to complete and get the exit code
  return process.exitCode;
}
