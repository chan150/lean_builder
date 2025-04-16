import 'dart:io';
import 'package:path/path.dart' as path;

void main(List<String> args) async {
  final stopwatch = Stopwatch()..start();

  // Configuration
  final sourceFile = 'bin/lean_builder.dart';
  final executableName = '.dart_tool/build/code_genie${Platform.isWindows ? '.exe' : ''}';
  final compileArgs = [
    'compile',
    'exe',
    sourceFile,
    '-o',
    executableName,
    // Add optimization flags for faster compilation
    '--verbosity=warning', // Reduces output noise
    '--target-os=${Platform.operatingSystem}', // Specify current OS only
  ];
  // Check if we need to recompile
  final shouldCompile = await shouldRecompile(sourceFile, executableName);

  // Compile if needed
  if (shouldCompile) {
    print('⏳ Compiling $sourceFile to executable...');

    final result = await Process.run('dart', compileArgs);

    if (result.exitCode != 0) {
      print('❌ Compilation failed:');
      print(result.stderr);
      exit(1);
    }

    // Make the file executable
    await Process.run('chmod', ['+x', executableName]);
    print('✅ Compilation completed in ${stopwatch.elapsed.inMilliseconds}ms');
  }

  // Run the executable
  print('\n🚀 Running the executable:');
  final process = await Process.start('./$executableName', args);
  process.stdout.pipe(stdout);
  process.stderr.pipe(stderr);
  final exitCode = await process.exitCode;
  print('\n✅ Executable finished with exit code: $exitCode');
}

Future<bool> shouldRecompile(String sourceFile, String executableName) async {
  final executable = File(executableName);
  final sourceFileObj = File(sourceFile);
  final pubspecFile = File('pubspec.yaml');

  // Verify source file exists
  if (!sourceFileObj.existsSync()) {
    print('❌ Source file $sourceFile does not exist.');
    exit(1);
  }

  // If executable doesn't exist, we need to compile
  if (!executable.existsSync()) {
    print('🔄 Executable not found, compiling...');
    return true;
  }

  final execLastModified = executable.lastModifiedSync();

  // Check source file modification time
  if (sourceFileObj.lastModifiedSync().isAfter(execLastModified)) {
    print('🔄 Source code is newer than executable, recompiling...');
    return true;
  }

  // Check pubspec.yaml modification time
  if (pubspecFile.existsSync() && pubspecFile.lastModifiedSync().isAfter(execLastModified)) {
    print('🔄 pubspec.yaml has changed, recompiling...');
    return true;
  }

  print('✅ Executable is up to date, skipping compilation.');
  return false;
}
