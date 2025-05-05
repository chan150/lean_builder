import 'package:lean_builder/src/build_script/parsed_builder_entry.dart';

const _leanBuilderImport = 'package:lean_builder/runner.dart';
const _isolateImport = 'dart:isolate';

String generateBuildScript(List<BuilderDefinitionEntry> entries) {
  assert(entries.isNotEmpty);
  final importPrefixes = <String, String>{};

  final buffer = StringBuffer();
  buffer.writeln('// This is an auto-generated build script.');
  buffer.writeln('// Do not modify this file directly.');

  final imports = <String>{_isolateImport, _leanBuilderImport};
  for (final entry in entries) {
    imports.add(entry.import);
    if (entry.annotationsTypeMap != null) {
      for (final annotation in entry.annotationsTypeMap!) {
        if (annotation.import != null) {
          imports.add(annotation.import!);
        }
      }
    }
  }
  for (final import in imports) {
    final prefix = importPrefixes[import] ??= 'i${importPrefixes.length + 1}';
    buffer.writeln('import \'$import\' as $prefix;');
  }
  final builderPrefix = importPrefixes[_leanBuilderImport]!;
  final isolatePrefix = importPrefixes[_isolateImport]!;

  buffer.writeln('final _builders = <$builderPrefix.BuilderEntry>[');
  for (final entry in entries) {
    final prefix = importPrefixes[entry.import]!;
    buffer.writeln('$builderPrefix.BuilderEntry');

    final typeRegMap = <String, String>{};
    for (final reg in {...?entry.annotationsTypeMap}) {
      final importPrefix = importPrefixes[reg.import];
      typeRegMap[[if (importPrefix != null) importPrefix, reg.name].join('.')] = reg.srcId;
    }

    final type = entry.builderType;
    if (type.isShared) {
      buffer.write('.sharedPart(');
    } else if (type.isLibrary) {
      buffer.write('.library(');
    } else {
      buffer.write('(');
    }

    final props = [
      '\'${entry.key}\'',
      if (type.isShared || type.isLibrary)
        entry.expectsOptions ? '$prefix.${entry.generatorName}.new' : '(_)=> $prefix.${entry.generatorName}()',
      if (entry.generateToCache != null) 'generateToCache: ${entry.generateToCache}',
      if (typeRegMap.isNotEmpty)
        'annotationsTypeMap: {${typeRegMap.entries.map((e) => "${e.key}: '${e.value}' ").join(', ')}}',
      if (entry.allowSyntaxErrors != null) 'allowSyntaxErrors: ${entry.allowSyntaxErrors}',
      if (entry.generateFor?.isNotEmpty == true) 'generateFor: {${entry.generateFor!.map((e) => "'$e'").join(', ')}}',
      if (entry.runsBefore?.isNotEmpty == true) 'runsBefore: {${entry.runsBefore!.map((e) => "'$e'").join(', ')}}',
      if (entry.options?.isNotEmpty == true) 'options: ${entry.options!.map((k, v) => MapEntry("'$k'", v))}',
    ];
    buffer.writeln('${props.join(',\n')},');

    buffer.writeln('),');
  }
  buffer.writeln('];');

  buffer.write('''
  void main(List<String> args, $isolatePrefix.SendPort? sendPort)  async{
    final result =  await $builderPrefix.runBuilders(_builders, args);
    sendPort?.send(result);
  }
  ''');
  return buffer.toString();
}
