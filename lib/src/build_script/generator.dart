import 'package:lean_builder/src/build_script/parsed_builder_entry.dart';

String generateBuildScript(List<BuilderDefinitionEntry> entries, String scriptHash) {
  assert(entries.isNotEmpty);
  final importPrefixes = <String, String>{};

  final buffer = StringBuffer();
  buffer.writeln('// This is an auto-generated build script.');
  buffer.writeln('// Do not modify this file directly.');
  buffer.writeln('import \'dart:isolate\' as i0;');
  buffer.writeln('import \'package:lean_builder/runner.dart\' as i1;');
  for (final entry in entries) {
    final prefix = importPrefixes[entry.import] ??= 'i${importPrefixes.length + 2}';
    buffer.writeln('import \'${entry.import}\' as $prefix;');
  }
  buffer.writeln('final _builders = <i1.BuilderEntry>[');
  for (final entry in entries) {
    final prefix = importPrefixes[entry.import]!;
    buffer.writeln('i1.BuilderEntry(');
    final props = [
      '\'${entry.key}\'',
      '$prefix.${entry.builderFactory}',
      'generateToCache: ${entry.generateToCache}',
      if (entry.generateFor?.isNotEmpty == true) 'generateFor: ${entry.generateFor}',
      if (entry.runsBefore?.isNotEmpty == true) 'runsBefore: ${entry.runsBefore}',
      if (entry.options?.isNotEmpty == true) 'options: ${entry.options.toString()}',
    ];
    buffer.writeln('${props.join(',\n')},');

    buffer.writeln('),');
  }
  buffer.writeln('];');

  buffer.write('''
  void main(List<String> args, i0.SendPort? sendPort)  async{
    final result =  await i1.runBuilders(_builders, args, '$scriptHash');
    sendPort?.send(result);
  }
  ''');
  return buffer.toString();
}
