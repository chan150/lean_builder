import 'package:collection/collection.dart' show IterableExtension;
import 'package:lean_builder/src/runner/builder_entry.dart';
import 'package:lean_builder/src/runner/command/lean_command_runner.dart';

/// {@template run_builders}
/// Entry point for executing Lean Builder commands with the provided builders.
///
/// This function:
/// 1. Creates a command runner configured with the provided builders
/// 2. Filters out VM service arguments that shouldn't be passed to the runner
/// 3. Executes the requested command with the remaining arguments
///
/// [builders] The list of builder entries to use for building
/// [args] The command-line arguments to parse and execute
///
/// Returns an exit code (0 for success, non-zero for failure)
/// {@endtemplate}
Future<int> runBuilders(List<BuilderEntry> builders, List<String> args) async {
  final LeanCommandRunner runner = LeanCommandRunner(builderEntries: builders);
  final Iterable<String> subArgs = args.whereNot((String e) => e == '--enable-vm-service');
  return await runner.run(subArgs) ?? 0;
}
