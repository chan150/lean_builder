import 'package:example/src/annotations.dart';
import 'package:glob/glob.dart';
import 'package:lean_builder/builder.dart';
import 'utils.dart';

@LeanGenerator({'.lib.dart'}, applies: {'Serializable2'}, generateToCache: false)
class SerializableGenerator extends GeneratorForAnnotatedClass<Serializable> {
  @override
  Future<String> generateForClass(buildStep, element, annotation) async {
    final buffer = StringBuffer();
    final writeln = buffer.writeln;
    writeln('// ${annotation.constant}');
    writeln('class Gen${element.name} {');
    for (final field in element.fields) {
      writeln('/// ${toLowerCase(field.name)}');
      writeln('final ${field.type} ${field.name};');
    }
    writeln('}');

    return buffer.toString();
  }
}

@LeanGenerator({'.all.dart'}, key: 'Serializable2')
class SerializableGeneratorAll extends GeneratorForAnnotatedClass<Serializable2> {
  @override
  dynamic generateForClass(buildStep, element, annotation) async {
    print('Generating for ${buildStep.asset.shortUri} with annotation $annotation');
    final glob = Glob('**.lib.dart');
    final files = buildStep.findAssets(glob);
    return '// output ${files.length} found';
  }
}
