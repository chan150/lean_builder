import 'package:collection/collection.dart';
import 'package:lean_builder/src/runner/builder_entry.dart';
import 'package:lean_builder/src/runner/command/lean_command_runner.dart';

Future<int> runBuilders(List<BuilderEntry> builders, List<String> args, String scriptHash) async {
  final runner = LeanCommandRunner(buildScriptHash: scriptHash, builderEntries: builders);
  return await runner.run([...args.whereNot((e) => e.startsWith('--'))]) ?? 0;
}
