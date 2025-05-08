import 'package:args/command_runner.dart' show CommandRunner;
import 'package:lean_builder/runner.dart';
import 'package:lean_builder/src/runner/command/build_command.dart';
import 'package:lean_builder/src/runner/command/watch_command.dart';

/// {@template lean_command_runner}
/// A command runner for the Lean Builder system.
///
/// This class provides a command-line interface for the Lean Builder system,
/// registering the available commands and handling their execution.
///
/// Currently supports:
/// - `build`: Run a one-time build
/// - `watch`: Start a continuous build server that watches for changes
/// {@endtemplate}
class LeanCommandRunner extends CommandRunner<int> {
  /// The list of builder entries to use for building
  final List<BuilderEntry> builderEntries;

  /// {@macro lean_command_runner}
  LeanCommandRunner({required this.builderEntries})
    : super(
        'lean_builder',
        'A streamlined Dart build system that applies lean principles to minimize waste and maximize speed.',
      ) {
    addCommand(BuildCommand());
    addCommand(WatchCommand());
  }
}
