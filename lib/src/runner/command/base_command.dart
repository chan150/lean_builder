import 'package:args/command_runner.dart';
import 'package:lean_builder/src/logger.dart';

abstract class BaseCommand<T> extends Command<T> {
  BaseCommand() {
    _addParserFlags();
  }

  void _addParserFlags() {
    argParser.addFlag(
      'dev',
      negatable: false,
      help: 'Run in development mode, this will use JIT compilation and delete all build outputs before each run.',
    );
    argParser.addFlag('verbose', abbr: 'v', negatable: false, help: 'Enable verbose logging.');
  }

  void prepare() {
    if (argResults?['verbose'] == true) {
      Logger.level = LogLevel.fine;
    }
  }
}
