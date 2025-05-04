import 'package:lean_builder/builder.dart';

class LeanBuilder {
  static const name = 'LeanBuilder';
  final String key;
  final bool generateToCache;
  final Set<String> generateFor;
  final Set<String> runsBefore;
  final Set<Type> annotations;

  const LeanBuilder({
    required this.key,
    this.annotations = const {},
    this.generateToCache = false,
    this.generateFor = const {},
    this.runsBefore = const {},
  });
}

@LeanBuilder(key: 'my_builder', annotations: {String})
class MyBuilder extends SharedPartBuilder {
  MyBuilder(super.generators);
}
