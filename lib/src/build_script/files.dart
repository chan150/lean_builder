import 'package:path/path.dart' as p;

const cacheDir = '.dart_tool/lean_build';
final scriptOutput = p.join(cacheDir, 'script/build.dart');
final scriptExecutable = p.join(cacheDir, 'script/build');
final generatedDir = p.join(cacheDir, 'generated');
