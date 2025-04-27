import 'dart:async';
import 'dart:convert';

import 'package:dart_style/dart_style.dart';
import 'package:lean_builder/src/element/element.dart';
import 'package:lean_builder/src/logger.dart';
import 'package:path/path.dart' as p;
import 'build_step.dart';
import 'builder.dart';
import 'generator/generated_output.dart';
import 'generator/generator.dart';

const defaultFileHeader = '// GENERATED CODE - DO NOT MODIFY BY HAND';

String _defaultFormatOutput(String code) =>
    DartFormatter(languageVersion: DartFormatter.latestLanguageVersion).format(code);

final _headerLine = '// '.padRight(77, '*');

/// A [Builder] wrapping on one or more [Generator]s.
abstract class _Builder extends Builder {
  /// Function that determines how the generated code is formatted.
  ///
  /// The `languageVersion` is the version to parse the file with, but it may be
  /// overridden using a language version comment in the file.
  final String Function(String code) formatOutput;

  /// The generators run for each targeted library.
  final List<Generator> _generators;

  final String _header;

  /// Whether to include or emit the gen part descriptions. Defaults to true.
  final bool _writeDescriptions;

  /// Whether to allow syntax errors in input libraries.
  final bool allowSyntaxErrors;

  @override
  final Map<String, Set<String>> buildExtensions;

  @override
  Set<String> get allowedExtensions => buildExtensions.values.expand((e) => e).toSet();

  /// Wrap [_generators] to form a [Builder]-compatible API.
  ///
  /// If available, the `build_extensions` option will be extracted from
  /// [options] to allow output files to be generated into a different directory
  _Builder(
    this._generators, {
    required this.formatOutput,
    Set<String> outputExtensions = const {'.g.dart'},
    String? header,
    bool? writeDescriptions,
    this.allowSyntaxErrors = false,
    BuilderOptions? options,
  }) : buildExtensions = validatedBuildExtensionsFrom(options != null ? Map.of(options.config) : null, {
         '.dart': outputExtensions,
       }),
       _writeDescriptions = writeDescriptions ?? true,
       _header = (header ?? defaultFileHeader).trim();

  @override
  bool shouldBuild(BuildCandidate candidate) {
    return candidate.path.endsWith('.dart') && candidate.hasTopLevelMetadata;
  }

  @override
  Future<void> build(BuildStep buildStep) async {
    final resolver = buildStep.resolver;
    if (!resolver.isLibrary(buildStep.asset)) {
      return;
    }
    final library = resolver.resolveLibrary(
      buildStep.asset,
      allowSyntaxErrors: allowSyntaxErrors,
      preResolveTopLevelMetadata: true,
    );
    await generateForLibrary(library, buildStep);
  }

  Stream<GeneratedOutput> _generate(LibraryElement library, List<Generator> generators, BuildStep buildStep) async* {
    for (var i = 0; i < generators.length; i++) {
      final gen = generators[i];
      var msg = 'Running $gen';
      if (generators.length > 1) {
        msg = '$msg - ${i + 1} of ${generators.length}';
      }
      Logger.fine(msg);
      var createdUnit = await gen.generate(library, buildStep);

      if (createdUnit == null) {
        continue;
      }

      createdUnit = createdUnit.trim();
      if (createdUnit.isEmpty) {
        continue;
      }
      yield GeneratedOutput(gen, createdUnit);
    }
  }

  Future<void> generateForLibrary(LibraryElement library, BuildStep buildStep) async {
    final generatedOutputs = await _generate(library, _generators, buildStep).toList();
    if (generatedOutputs.isEmpty) return;

    final contentBuffer = StringBuffer();
    if (_header.isNotEmpty) {
      contentBuffer.writeln(_header);
    }

    final extension = buildStep.allowedExtensions.first;
    for (var item in generatedOutputs) {
      if (_writeDescriptions) {
        contentBuffer
          ..writeln()
          ..writeln(_headerLine)
          ..writeAll(LineSplitter.split(item.generatorDescription).map((line) => '// $line\n'))
          ..writeln(_headerLine)
          ..writeln();
      }

      contentBuffer.writeln(item.output);
    }

    await writeOutput(buildStep, contentBuffer.toString(), extension);
  }

  FutureOr<void> writeOutput(BuildStep buildStep, String content, String extension) {
    try {
      content = formatOutput(content);
    } catch (e, stack) {
      final fileResolver = buildStep.resolver.fileResolver;
      final output = buildStep.asset.uriWithExtension(extension);
      Logger.error(
        '''An error `${e.runtimeType}` occurred while formatting the generated source for `${buildStep.asset.shortUri}`
which was output to `${fileResolver.toShortUri(output)}`.
This may indicate an issue in the generator, the input source code, or in the source formatter.''',
        stackTrace: stack,
      );
      return Future.value(null);
    }
    return buildStep.writeAsString(content, extension: extension);
  }

  @override
  String toString() => 'Generating $buildExtensions: ${_generators.join(', ')}';
}

class LibraryBuilder extends _Builder {
  /// Wrap [generator] as a [Builder] that generates Dart library files.
  ///
  /// [outputExtensions] indicates what files will be created for each input

  /// [formatOutput] is called to format the generated code. Defaults to
  /// using the standard [DartFormatter] and writing a comment specifying the
  /// default format width of 80..
  ///
  /// [writeDescriptions] adds comments to the output used to separate the
  /// sections of the file generated from different generators, and reveals
  /// which generator produced the following output.
  /// If `null`, [writeDescriptions] is set to true which is the default value.
  /// If [writeDescriptions] is false, no generator descriptions are added.
  ///
  /// [header] is used to specify the content at the top of each generated file.
  /// If `null`, the content of [defaultFileHeader] is used.
  /// If [header] is an empty `String` no header is added.
  ///
  /// [allowSyntaxErrors] indicates whether to allow syntax errors in input
  /// libraries.
  LibraryBuilder(
    Generator generator, {
    super.formatOutput = _defaultFormatOutput,
    required super.outputExtensions,
    super.writeDescriptions,
    super.header,
    super.allowSyntaxErrors,
    super.options,
  }) : super([generator]) {
    for (final ext in buildExtensions.values.expand((e) => e)) {
      if (ext == SharedPartBuilder.extension) {
        throw ArgumentError('The LibraryBuilder cannot be used with the shared part extension');
      }
    }
  }
}

class SharedPartBuilder extends _Builder {
  static const extension = '.g.dart';

  /// A [Builder] that writes partial content, to the output writer
  ///
  /// [formatOutput] is called to format the generated code. Defaults to
  /// [DartFormatter.format].
  ///
  /// [allowSyntaxErrors] indicates whether to allow syntax errors in input
  /// libraries.
  SharedPartBuilder(
    super._generators, {
    super.formatOutput = _defaultFormatOutput,
    super.allowSyntaxErrors,
    super.writeDescriptions,
  }) : super(outputExtensions: {extension}, header: '');

  @override
  FutureOr<void> writeOutput(BuildStep buildStep, String content, String extension) {
    if (extension != SharedPartBuilder.extension) {
      throw ArgumentError('The Shared extension must be $extension');
    }
    if (!buildStep.hasValidPartDirectiveFor(extension)) {
      final outputUri = buildStep.asset.uriWithExtension(extension);
      final part = p.relative(outputUri.path, from: p.dirname(buildStep.asset.uri.path));
      throw ArgumentError(
        'The input library must have a part directive for the generated part\n'
        'file. Please add a part directive (part \'$part\';) to the input library ${buildStep.inputLibrary.src.shortUri}',
      );
    }
    return super.writeOutput(buildStep, content, extension);
  }
}

/// Returns a valid buildExtensions map created from [optionsMap] or
/// returns [defaultExtensions] if no 'build_extensions' key exists.
///
/// Modifies [optionsMap] by removing the `build_extensions` key from it, if
/// present.
Map<String, Set<String>> validatedBuildExtensionsFrom(
  Map<String, dynamic>? optionsMap,
  Map<String, Set<String>> defaultExtensions,
) {
  final extensionsOption = optionsMap?.remove('build_extensions');
  if (extensionsOption == null) {
    // defaultExtensions are provided by the builder author, not the end user.
    // It should be safe to skip validation.
    return defaultExtensions;
  }

  if (extensionsOption is! Map) {
    throw ArgumentError('Configured build_extensions should be a map from inputs to outputs.');
  }

  final result = <String, Set<String>>{};

  for (final entry in extensionsOption.entries) {
    final input = entry.key;
    if (input is! String || !input.endsWith('.dart')) {
      throw ArgumentError(
        'Invalid key in build_extensions option: `$input` '
        'should be a string ending with `.dart`',
      );
    }

    final output = (entry.value is List) ? entry.value as List : [entry.value];

    for (var i = 0; i < output.length; i++) {
      final o = output[i];
      if (o is! String || (i == 0 && !o.endsWith('.dart'))) {
        throw ArgumentError(
          'Invalid output extension `${entry.value}`. It should be a string '
          'or a list of strings with the first ending with `.dart`',
        );
      }
    }

    result[input] = output.cast<String>().toSet();
  }

  if (result.isEmpty) {
    throw ArgumentError('Configured build_extensions must not be empty.');
  }

  return result;
}
