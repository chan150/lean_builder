import 'package:args/command_runner.dart';

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
  }
}
