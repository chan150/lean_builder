import 'dart:io';
import 'package:path/path.dart' as path;

void main(List<String> args) async {
  final stopwatch = Stopwatch()..start();

  // Configuration
  final sourceFile = 'bin/lean_builder.dart';
  final executableName = '.dart_tool/lean_build/lean_build${Platform.isWindows ? '.exe' : ''}';
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

  final executableFile = File(executableName);

  // Compile if needed
  if (!executableFile.existsSync()) {
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
