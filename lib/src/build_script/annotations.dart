import 'package:meta/meta_meta.dart';

const kBuilderAnnotationsPrefix = r'Lean';

@Target({TargetKind.classType})
class LeanBuilder {
  final String? key;
  final bool generateToCache;
  final Set<String>? generateFor;
  final Set<String>? runsBefore;
  final Set<Type>? annotations;

  const LeanBuilder({this.key, this.annotations, this.generateToCache = false, this.generateFor, this.runsBefore});
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
