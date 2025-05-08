import 'package:args/command_runner.dart' show Command;
import 'package:lean_builder/src/logger.dart';

/// {@template base_command}
/// Base class for all Lean Builder commands.
///
/// This abstract class provides common functionality for all commands in the
/// Lean Builder system, including:
/// - Standard command-line flags (verbose, dev mode)
/// - Logging configuration
/// - Common preparation steps
///
/// All commands should extend this class to ensure consistent behavior
/// and configuration options.
/// {@endtemplate}
abstract class BaseCommand<T> extends Command<T> {
  /// {@macro base_command}
  BaseCommand() {
    _addParserFlags();
  }

  void _addParserFlags() {
    argParser.addFlag(
      'dev',
      negatable: false,
      help:
          'Run in development mode, this will use JIT compilation and delete all build outputs before each run.'
          'When used with `watch` command, it will activate hot reload mode.',
    );
    argParser.addFlag('verbose', abbr: 'v', negatable: false, help: 'Enable verbose logging.');
  }

  /// {@template base_command.prepare}
  /// Prepares the command for execution.
  ///
  /// This method should be called before executing the command's logic.
  /// It configures the logging level based on command-line arguments.
  /// {@endtemplate}
  void prepare() {
    if (argResults?['verbose'] == true) {
      Logger.level = LogLevel.fine;
    }
  }
}
