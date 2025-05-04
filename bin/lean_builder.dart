import 'dart:io';
import 'dart:isolate';

import 'package:lean_builder/src/build_script/compile.dart';
import 'package:lean_builder/src/logger.dart';
import 'package:lean_builder/src/runner/command/utils.dart';
import 'utils.dart';
import 'package:path/path.dart' as p;
import 'runner.dart' as runner;

void main(List<String> args) async {
  final isDevMode = args.contains('--dev');
  if (!isDevMode) {
    var runnerExePath = Isolate.resolvePackageUriSync(Uri.parse('package:lean_builder/bin/runner.aot'));
    if (runnerExePath == null) {
      Logger.error('Could not resolve the path to runner.aot');
      exit(1);
    }
    runnerExePath = runnerExePath.replace(pathSegments: runnerExePath.pathSegments.where((e) => e != 'lib'));
    final runtimePath = getRuntimePath();
    final process = await Process.start(runtimePath, [
      runnerExePath.path,
      ...args,
    ], mode: ProcessStartMode.inheritStdio);
    final exitCode = await process.exitCode;
    if (exitCode == 2) {
      Logger.info('No Assets to process. Exiting.');
      exit(0);
    } else if (exitCode != 0) {
      Logger.error('Process exited with code $exitCode');
      exit(exitCode);
    }
  } else {
    await runner.main(args);
  }

  if (isDevMode) {
    Logger.warning('Running in development mode');
    await _spawnBuild(args);
  } else {
    final scriptPath = p.join(p.current, '.dart_tool/lean_build/script/build.dart');
    await _runAot(scriptPath, args);
  }
  // final scriptPath = p.join(p.current, '.dart_tool/lean_build/script/build.dart');
  // await Process.start('dart', ['run', scriptPath, ...args], mode: ProcessStartMode.inheritStdio);
  // final events = DirectoryWatcher(p.join(Directory.current.path, 'lib')).events;
  //
  // events.listen((event) async {
  //   Logger.info('File changed: ${event.path}');
  //   final stopWatch = Stopwatch()..start();
  //   await _spawnBuild(args);
  //   // final process = await Process.start('dart', ['run', scriptPath, ...args], mode: ProcessStartMode.inheritStdio);
  //   // final exitCode = await process.exitCode;
  //   Logger.info('Build completed in ${stopWatch.elapsed.formattedMS}');
  // });
}

Future<void> _spawnBuild(List<String> args) async {
  final uri = Uri.parse(p.join(p.current, '.dart_tool/lean_build/script/build.dart'));
  final receive = ReceivePort();
  await Isolate.spawnUri(uri, args, receive.sendPort);
  await receive.first;
}

// Future<int> _runJit(String scriptPath, List<String> args) async {
//   Logger.warning('Running in JIT mode. This may be slower than AOT.');
//
//   return _runProcess('dart', ['run', scriptPath, ...args]);
// }

Future<int> _runAot(String scriptPath, List<String> args) async {
  final executableFile = File(getExecutablePath());

  if (!executableFile.existsSync()) {
    final stopwatch = Stopwatch()..start();
    Logger.info('Compiling build script to AOT executable...');
    compileScript(scriptPath);
    Logger.info('Compilation completed in ${stopwatch.elapsed.formattedMS}');
  }

  return _runProcess(getRuntimePath(), [executableFile.path, ...args]);
}

Future<int> _runProcess(String executable, List<String> arguments) async {
  final process = await Process.start(executable, arguments, mode: ProcessStartMode.inheritStdio);
  // Wait for the process to complete and get the exit code
  return process.exitCode;
}
