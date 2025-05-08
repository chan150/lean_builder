import 'dart:io' show File, Directory, exit, Platform, Process, ProcessStartMode;
import 'dart:isolate' show Isolate;

import 'package:lean_builder/src/build_script/compile.dart';
import 'package:lean_builder/src/build_script/paths.dart';
import 'package:lean_builder/src/logger.dart';
import 'package:lean_builder/src/runner/command/utils.dart';
import 'package:path/path.dart' as p;

void main(List<String> args) async {
  final bool isDevMode = args.contains('--dev');
  final bool isWatchMode = args.contains('watch');

  Uri? runnerExePath = Isolate.resolvePackageUriSync(Uri.parse('package:lean_builder/bin/runner.aot'));
  if (runnerExePath == null) {
    Logger.error('Could not resolve the path to runner.aot');
    exit(1);
  }
  runnerExePath = runnerExePath.replace(pathSegments: runnerExePath.pathSegments.where((String e) => e != 'lib'));
  final String runtimePath = _getRuntimePath();
  final Process process = await Process.start(runtimePath, <String>[
    runnerExePath.path,
    ...args,
  ], mode: ProcessStartMode.inheritStdio);
  final int exitCode = await process.exitCode;
  if (exitCode == 2) {
    if (!isWatchMode && !isDevMode) {
      Logger.info('No Assets to process. Exiting.');
      exit(0);
    }
  } else if (exitCode != 0) {
    Logger.error('Process exited with code $exitCode');
    exit(exitCode);
  }

  final String scriptAbsPath = p.join(p.current, scriptOutput);

  if (isDevMode) {
    invalidateExecutable();
    await _runJit(scriptAbsPath, args, enableVmService: isWatchMode && isDevMode);
  } else {
    await _runAot(scriptAbsPath, args);
  }
}

Future<int> _runJit(String scriptPath, List<String> args, {required bool enableVmService}) async {
  Logger.warning('Running in JIT mode. This may be slower than AOT.');
  return _runProcess('dart', <String>[if (enableVmService) '--enable-vm-service', scriptPath, ...args]);
}

Future<int> _runAot(String scriptPath, List<String> args) async {
  final File executableFile = File(getExecutablePath());

  if (!executableFile.existsSync()) {
    final Stopwatch stopwatch = Stopwatch()..start();
    Logger.info('Compiling build script to AOT executable...');
    compileScript(scriptPath);
    Logger.info('Compilation completed in ${stopwatch.elapsed.formattedMS}');
  }

  return _runProcess(_getRuntimePath(), <String>[executableFile.path, ...args]);
}

Future<int> _runProcess(String executable, List<String> arguments) async {
  final Process process = await Process.start(executable, arguments, mode: ProcessStartMode.inheritStdio);
  // Wait for the process to complete and get the exit code
  return process.exitCode;
}

String _getRuntimePath() {
  final String dartExecutable = Platform.resolvedExecutable;
  final String dartSdkDir = Directory(dartExecutable).parent.path;
  return '$dartSdkDir${Platform.pathSeparator}dartaotruntime';
}
