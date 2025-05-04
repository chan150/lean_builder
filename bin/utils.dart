import 'dart:io';

String getRuntimePath() {
  final dartExecutable = Platform.resolvedExecutable;
  final dartSdkDir = Directory(dartExecutable).parent.path;
  return '$dartSdkDir${Platform.pathSeparator}dartaotruntime';
}
