import 'package:collection/collection.dart';
import 'package:lean_builder/src/runner/builder_entry.dart';
import 'package:lean_builder/src/runner/command/lean_command_runner.dart';

Future<int> runBuilders(List<BuilderEntry> builders, List<String> args) async {
  final LeanCommandRunner runner = LeanCommandRunner(builderEntries: builders);
  final Iterable<String> subArgs = args.whereNot((String e) => e == '--enable-vm-service');
  return await runner.run(subArgs) ?? 0;
}
