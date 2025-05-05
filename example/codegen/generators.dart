import 'dart:async';

import 'package:example/src/annotations.dart';
import 'package:lean_builder/builder.dart';

@LeanGenerator.shared(options: {'feature1': true}, generateFor: {'lib/**.dart'})
class SerializableGenerator extends GeneratorForAnnotatedClass<Serializable> {
  final BuilderOptions options;
  SerializableGenerator(this.options);

  @override
  String generateForClass(buildStep, element, annotation) {
    final buffer = StringBuffer();
    buffer.writeln('class Gen${element.name} {');
    for (final field in element.fields) {
      buffer.writeln('  final ${field.type} ${field.name};');
    }
    buffer.writeln('}');

    return buffer.toString();
  }
}

@LeanBuilder()
class CustomerBuilder extends Builder {
  @override
  Set<String> get outputExtensions => {'.json'};

  @override
  bool shouldBuildFor(BuildCandidate candidate) {
    return candidate.extension == '.txt';
  }

  @override
  FutureOr<void> build(BuildStep buildStep) {
    throw UnimplementedError();
  }
}
