import 'dart:io';
import 'package:path/path.dart' as path;

void main(List<String> args) async {
  final stopwatch = Stopwatch()..start();

  // Configuration
  final sourceFile = 'bin/lean_builder.dart';
  final snapshotPath = '.dart_tool/lean_build/lean_build';

  // Create directory if needed
  await Directory(snapshotPath).create(recursive: true);

  // Compile AOT snapshot if needed
  final snapshotFile = File(snapshotPath);
  if (!snapshotFile.existsSync()) {
    print('⏳ Compiling $sourceFile to AOT snapshot...');

    final compileArgs = ['compile', 'exe', sourceFile, '-o', snapshotPath];

    final result = await Process.run('dart', compileArgs);

    if (result.exitCode != 0) {
      print('❌ Compilation failed:');
      print(result.stderr);
      exit(1);
    }

    print('✅ AOT snapshot compiled in ${stopwatch.elapsed.inMilliseconds}ms');
  }
  final dartExecutable = Platform.resolvedExecutable;
  final sdkDir = path.dirname(dartExecutable);
  // Run the AOT snapshot
  print('\nRunning the AOT snapshot:');

  final process = await Process.start(snapshotPath, [...args]);

  process.stdout.pipe(stdout);
  process.stderr.pipe(stderr);
  final exitCode = await process.exitCode;
  print('\n✅ AOT snapshot execution finished with exit code: $exitCode');
}
