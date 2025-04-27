import 'package:lean_builder/src/runner/builder_entry.dart';
import 'package:lean_builder/src/runner/command/lean_command_runner.dart';

Future<void> runBuilders(List<BuilderEntry> builders, List<String> args, String scriptHash) async {
  final runner = LeanCommandRunner(buildScriptHash: scriptHash, builderEntries: builders);
  await runner.run(args);
}
