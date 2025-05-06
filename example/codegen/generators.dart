import 'package:example/src/annotations.dart';
import 'package:lean_builder/builder.dart';

@LeanGenerator({'.lib.dart'})
class SerializableGenerator extends GeneratorForAnnotatedClass<Serializable> {
  @override
  Future<String> generateForClass(buildStep, element, annotation) async {
    final buffer = StringBuffer();
    final writeln = buffer.writeln;
    writeln('class Gen${element.name} {');
    for (final field in element.fields) {
      writeln('final ${field.type} ${field.name};');
    }
    writeln('}');

    return buffer.toString();
  }
}
