import 'package:lean_builder/src/builder/builder_impl.dart';
import 'package:lean_builder/src/builder/runner/build_runner.dart';
import 'package:lean_builder/src/builder/runner/builder_entry.dart';
import 'my_builder.dart';

void main(List<String> args) async {
  runBuilders([
    BuilderEntry(
      'my_builder',
      (options) => SharedPartBuilder([MyGenerator()]),
      hideOutput: false,
      generateFor: ['lib/**/*.dart'],
    ),
  ], args);
}
