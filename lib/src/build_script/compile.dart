import 'dart:io' show Directory, File, Platform, Process;

import 'package:frontend_server_client/frontend_server_client.dart';

import 'errors.dart';
import 'paths.dart' as paths;
import 'package:path/path.dart' as p;

/// Compiles the build script at the given path to a dill kernel file.
Future<void> compileKernel(String scriptPath, String scriptKernelPath) async {
  try {
    final dir = Directory(p.dirname(scriptKernelPath));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    final client = await FrontendServerClient.start(
      scriptPath,
      scriptKernelPath,
      'lib/_internal/vm_platform_strong.dill',
      printIncrementalDependencies: true,
    );
    await client.compile();
    client.kill();
  } catch (e) {
    throw CompileError('Failed to compile the script: $e');
  }
}

/// Compiles the build script at the given path to an AOT snapshot.
///
/// Uses the Dart compiler to create an executable snapshot that can be
/// run more efficiently than interpreting the script each time.
/// Throws a [CompileError] if compilation fails.
///
/// @param scriptPath The path to the Dart script to be compiled
Future<void> compileToAotSnapshot(String scriptPath, String outputPath) async {
  try {
    final dir = Directory(p.dirname(outputPath));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    final result = await Process.run('dart', [
      'compile',
      'aot-snapshot',
      scriptPath,
      '-o',
      outputPath,
    ]);

    if (result.exitCode != 0) {
      throw CompileError('Failed to create JIT snapshot: ${result.stderr}');
    }
    if (!Platform.isWindows) {
      Process.runSync('chmod', <String>['+x', outputPath]);
    }
  } catch (e) {
    throw CompileError('Failed to compile JIT snapshot: $e');
  }
}

/// Deletes the compiled executable if it exists.
///
/// Used to force recompilation when the script has been modified
/// or when the executable may be in an inconsistent state.
void invalidateExecutable() {
  final File executable = File(paths.buildScriptAot);
  if (executable.existsSync()) {
    executable.deleteSync();
  }
}
