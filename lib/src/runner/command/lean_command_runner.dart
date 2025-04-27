import 'package:args/command_runner.dart';
import 'package:lean_builder/runner.dart';
import 'package:lean_builder/src/runner/command/build_command.dart';

class LeanCommandRunner extends CommandRunner<int> {
  final List<BuilderEntry> builderEntries;
  final String buildScriptHash;

  LeanCommandRunner({required this.buildScriptHash, required this.builderEntries})
    : super('lean_builder', 'A high efficiency Dart build system with lean principles.') {
    addCommand(BuildCommand());
    addCommand(WatchCommand());
  }
}
