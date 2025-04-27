import 'package:path/path.dart' as p;

const cacheDir = '.dart_tool/lean_build/script';
final scriptOutput = p.join(cacheDir, 'build.dart');
final scriptDigest = p.join(cacheDir, 'build.digest');
final scriptExecutable = p.join(cacheDir, 'build');
