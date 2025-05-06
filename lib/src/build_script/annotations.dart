import 'package:meta/meta_meta.dart';

const kBuilderAnnotationNames = {'LeanBuilder', 'LeanGenerator', 'LeanBuilderOverrides'};

@Target({TargetKind.classType})
class LeanBuilder {
  final String? key;
  final bool? generateToCache;
  final Set<String>? generateFor;
  final Set<String>? runsBefore;
  final Set<Type>? annotations;
  final Map<String, dynamic>? options;

  const LeanBuilder({
    this.key,
    this.annotations,
    this.generateToCache,
    this.generateFor,
    this.runsBefore,
    this.options,
  });
}

@Target({TargetKind.classType})
class LeanGenerator {
  final String? key;
  final bool? generateToCache;
  final Set<String>? generateFor;
  final Set<String>? runsBefore;
  final Set<Type>? annotations;
  final Set<String> outputExtensions;
  final bool? allowSyntaxErrors;
  final Map<String, dynamic>? options;

  const LeanGenerator(
    this.outputExtensions, {
    this.key,
    this.allowSyntaxErrors,
    this.generateToCache,
    this.annotations,
    this.generateFor,
    this.runsBefore,
    this.options,
  });

  const LeanGenerator.shared({
    this.key,
    this.allowSyntaxErrors,
    this.generateToCache,
    this.annotations,
    this.generateFor,
    this.runsBefore,
    this.options,
  }) : outputExtensions = const {};
}

@Target({TargetKind.topLevelVariable})
class LeanBuilderOverrides {
  const LeanBuilderOverrides();
}
