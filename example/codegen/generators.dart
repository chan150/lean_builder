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
      buffer.writeln('final ${field.type} ${field.name};');
    }
    buffer.writeln('}');

    return buffer.toString();
  }
}

@LeanBuilder(
  key: 'CustomKey',
  generateToCache: true,
  generateFor: {'lib/**.dart'},
  runsBefore: {'lean_builder'},
  options: {'feature1': true},
)
class CustomBuilder extends Builder {
  final BuilderOptions options;
  CustomBuilder(this.options);

  @override
  Set<String> get outputExtensions => {'.json'};

  @override
  bool shouldBuildFor(BuildCandidate candidate) {
    return candidate.isDartSource;
  }

  @override
  FutureOr<void> build(BuildStep buildStep) {
    print(options.config);
  }
}

@LeanBuilderOverrides()
const builderOverrides = [
  BuilderOverride(key: 'CustomKey', runsBefore: {'SerializableGenerator'}),
];
