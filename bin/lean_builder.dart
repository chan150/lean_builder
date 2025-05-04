import 'dart:io';
import 'dart:isolate';

import 'package:lean_builder/src/build_script/compile.dart';
import 'package:lean_builder/src/logger.dart';
import 'package:lean_builder/src/runner/command/utils.dart';
import 'package:path/path.dart' as p;

void main(List<String> args) async {
  final isDevMode = args.contains('--dev');
  final isWatchMode = args.contains('watch');

  var runnerExePath = Isolate.resolvePackageUriSync(Uri.parse('package:lean_builder/bin/runner.aot'));
  if (runnerExePath == null) {
    Logger.error('Could not resolve the path to runner.aot');
    exit(1);
  }
  runnerExePath = runnerExePath.replace(pathSegments: runnerExePath.pathSegments.where((e) => e != 'lib'));
  final runtimePath = _getRuntimePath();
  final process = await Process.start(runtimePath, [runnerExePath.path, ...args], mode: ProcessStartMode.inheritStdio);
  final exitCode = await process.exitCode;
  if (exitCode == 2 && !isWatchMode) {
    Logger.info('No Assets to process. Exiting.');
    exit(0);
  } else if (exitCode != 0) {
    Logger.error('Process exited with code $exitCode');
    exit(exitCode);
  }

  final scriptPath = p.join(p.current, '.dart_tool/lean_build/script/build.dart');

  if (isDevMode) {
    invalidateExecutable();
    Logger.warning('Running in development mode');
    await _runJit(scriptPath, args, enableVmService: isWatchMode && isDevMode);
  } else {
    await _runAot(scriptPath, args);
  }
}

Future<int> _runJit(String scriptPath, List<String> args, {required bool enableVmService}) async {
  Logger.warning('Running in JIT mode. This may be slower than AOT.');
  return _runProcess('dart', [if (enableVmService) '--enable-vm-service', scriptPath, ...args]);
}

Future<int> _runAot(String scriptPath, List<String> args) async {
  final executableFile = File(getExecutablePath());

  if (!executableFile.existsSync()) {
    final stopwatch = Stopwatch()..start();
    Logger.info('Compiling build script to AOT executable...');
    compileScript(scriptPath);
    Logger.info('Compilation completed in ${stopwatch.elapsed.formattedMS}');
  }

  return _runProcess(_getRuntimePath(), [executableFile.path, ...args]);
}

Future<int> _runProcess(String executable, List<String> arguments) async {
  final process = await Process.start(executable, arguments, mode: ProcessStartMode.inheritStdio);
  // Wait for the process to complete and get the exit code
  return process.exitCode;
}

String _getRuntimePath() {
  final dartExecutable = Platform.resolvedExecutable;
  final dartSdkDir = Directory(dartExecutable).parent.path;
  return '$dartSdkDir${Platform.pathSeparator}dartaotruntime';
}
