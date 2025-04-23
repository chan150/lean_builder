import 'package:lean_builder/runner.dart';
import 'my_builder.dart';

void main(List<String> args) async {
  runBuilders([BuilderEntry('my_builder', myBuilder)], args);
}
