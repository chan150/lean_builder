import 'with_annotation.dart' as wa;
import 'with_annotation.dart' as wah hide Annotation;
import 'with_annotation.dart' as was show Annotation;

export 'with_annotation.dart' hide Annotation;
export 'with_annotation.dart' show Annotation;
export 'with_annotation.dart';

final x = wa.Annotation();
final y = was.Annotation();
final z = wah.AnnotatedClass();
