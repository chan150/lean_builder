import 'package:example/src/annotations.dart';

@Serializable('Samp')
class SampleX {
  final String r;

  final String? t;

  const SampleX(this.t, [this.r = 'T233']);
}
