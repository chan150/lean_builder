import 'dart:async';

import 'package:lean_builder/src/builder/build_step.dart';
import 'package:lean_builder/src/builder/builder.dart';
import 'package:glob/glob.dart';

class BuilderEntry {
  final String key;
  final BuilderFactory builderFactory;
  final bool hideOutput;
  final List<String> generateFor;
  final BuilderOptions options;

  BuilderEntry(
    this.key,
    this.builderFactory, {
    this.hideOutput = false,
    this.generateFor = const [],
    Map<String, dynamic> options = const {},
  }) : options = BuilderOptions(options);

  Builder? _builder;

  Builder get builder {
    return _builder ??= builderFactory(options);
  }

  bool shouldGenerateFor(BuildCandidate candidate) {
    if (generateFor.isNotEmpty) {
      for (final pattern in generateFor) {
        final glob = Glob(pattern);
        if (glob.matches(candidate.asset.uri.path)) {
          return builder.shouldBuild(candidate);
        }
      }
      return false;
    }
    return builder.shouldBuild(candidate);
  }

  FutureOr<void> build(BuildStep buildStep) {
    return builder.build(buildStep);
  }
}
