import 'dart:convert';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:dart_style/dart_style.dart';
import 'package:lean_builder/src/logger.dart';
import 'package:lean_builder/src/resolvers/element/element.dart';
import 'package:lean_builder/src/resolvers/file_asset.dart';
import 'package:path/path.dart' as p;
import 'build_step.dart';
import 'builder.dart';
import 'generator/generated_output.dart';
import 'generator/generator.dart';

const defaultFileHeader = '// GENERATED CODE - DO NOT MODIFY BY HAND';

const dartFormatWidth = '// dart format width=80';

String _defaultFormatOutput(String code) =>
    DartFormatter(languageVersion: DartFormatter.latestLanguageVersion).format(code);

String _defaultFormatUnit(String code) {
  code = '$dartFormatWidth\n$code';
  return _defaultFormatOutput(code);
}

final _headerLine = '// '.padRight(77, '*');

const partIdRegExpLiteral = r'[A-Za-z_\d-]+';

final _partIdRegExp = RegExp('^$partIdRegExpLiteral\$');

/// A [Builder] wrapping on one or more [Generator]s.
abstract class _Builder extends Builder {
  /// Function that determines how the generated code is formatted.
  ///
  /// The `languageVersion` is the version to parse the file with, but it may be
  /// overridden using a language version comment in the file.
  final String Function(String code) formatOutput;

  /// The generators run for each targeted library.
  final List<Generator> _generators;

  /// possible extensions for generated files
  ///
  /// The first extension is the primary output, and the rest are
  /// additional outputs.
  ///
  /// this can not be empty
  final Set<String> generatedExtensions;

  final String _header;

  /// Whether to include or emit the gen part descriptions. Defaults to true.
  final bool _writeDescriptions;

  /// Whether to allow syntax errors in input libraries.
  final bool allowSyntaxErrors;

  @override
  final Map<String, Set<String>> buildExtensions;

  /// Wrap [_generators] to form a [Builder]-compatible API.
  ///
  /// If available, the `build_extensions` option will be extracted from
  /// [options] to allow output files to be generated into a different directory
  _Builder(
    this._generators, {
    required this.formatOutput,
    this.generatedExtensions = const {'.g.dart'},
    String? header,
    bool? writeDescriptions,
    this.allowSyntaxErrors = false,
    BuilderOptions? options,
  }) : buildExtensions = validatedBuildExtensionsFrom(options != null ? Map.of(options.config) : null, {
         '.dart': generatedExtensions,
       }),
       _writeDescriptions = writeDescriptions ?? true,
       _header = (header ?? defaultFileHeader).trim();

  @override
  Future<void> build(BuildStep buildStep) async {
    final resolver = buildStep.resolver;
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
      var msg = 'Running $gen for ${library.src.uri}';
      if (generators.length > 1) {
        msg = '$msg - ${i + 1} of ${generators.length}';
      }
      Logger.info(msg);
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

    var content = contentBuffer.toString();

    try {
      content = formatOutput(content);
    } catch (e, stack) {
      Logger.severe(
        '''
An error `${e.runtimeType}` occurred while formatting the generated source for
  `${library.src.uri}`
which was output to to extension
  `${buildStep.allowedExtensions.first}`.
This may indicate an issue in the generator, the input source code, or in the
source formatter.''',
        e,
        stack,
      );
    }

    final extension = buildStep.allowedExtensions.first;
    await buildStep.writeAsString(buildStep.asset, extension, content);
  }

  @override
  String toString() => 'Generating $generatedExtensions: ${_generators.join(', ')}';
}

class LibraryBuilder extends _Builder {
  /// Wrap [generator] as a [Builder] that generates Dart library files.
  ///
  /// [generatedExtension] indicates what files will be created for each `.dart`
  /// input.
  /// Defaults to `.g.dart`, however this should usually be changed to
  /// avoid conflicts with outputs from a [SharedPartBuilder].
  /// If [generator] will create additional outputs through the [BuildStep] they
  /// should be indicated in [additionalOutputExtensions].
  ///
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
    super.formatOutput = _defaultFormatUnit,
    super.generatedExtensions,
    super.writeDescriptions,
    super.header,
    super.allowSyntaxErrors,
    super.options,
  }) : super([generator]);
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
    if (defaultExtensions.isEmpty) {
      throw ArgumentError('Configured build_extensions must not be empty.');
    }
    for (final ext in defaultExtensions.values.first) {
      if (ext.isEmpty || ext[0] != '.') {
        throw ArgumentError('Extensions should be in the format of .*');
      }
    }
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

/// A [Builder] which generates content intended for `part of` files.
///
/// Generated files will be prefixed with a `partId` to ensure multiple
/// [SharedPartBuilder]s can produce non conflicting `part of` files. When the
/// `source_gen|combining_builder` is applied to the primary input these
/// snippets will be concatenated into the final `.g.dart` output.
///
/// This builder can be used when multiple generators may need to output to the
/// same part file but [PartBuilder] can't be used because the generators are
/// not all defined in the same location. As a convention most codegen which
/// generates code should use this approach to get content into a `.g.dart` file
/// instead of having individual outputs for each building package.
class SharedPartBuilder extends _Builder {
  /// Wrap [generators] as a [Builder] that generates `part of` files.
  ///
  /// [partId] indicates what files will be created for each `.dart`
  /// input. This extension should be unique as to not conflict with other
  /// [SharedPartBuilder]s. The resulting file will be of the form
  /// `<generatedExtension>.g.part`. If any generator in [generators] will
  /// create additional outputs through the [BuildStep] they should be indicated
  /// in [additionalOutputExtensions].
  ///
  /// [formatOutput] is called to format the generated code. Defaults to
  /// [DartFormatter.format].
  ///
  /// [allowSyntaxErrors] indicates whether to allow syntax errors in input
  /// libraries.
  SharedPartBuilder(super.generators, String partId, {super.formatOutput = _defaultFormatUnit, super.allowSyntaxErrors})
    : super(generatedExtensions: {'.$partId.g.part'}, header: '') {
    if (!_partIdRegExp.hasMatch(partId)) {
      throw ArgumentError.value(
        partId,
        'partId',
        '`partId` can only contain letters, numbers, `_` and `.`. '
            'It cannot start or end with `.`.',
      );
    }
  }
  //
  // @override
  // Future<void> generateForLibrary(LibraryElement library, BuildStep buildStep) {
  //    if(!buildStep.hasValidPartDirectiveFor('.g.part')) {
  //     throw ArgumentError(
  //       'The input library must have a part directive for the generated part '
  //       'file. Please add a part directive (${}) to the input library ${library.src.uri}',
  //     );
  //    }
  //   // This is a no-op. The combining builder will handle the output.
  // }
}

// @override
// Future<void> generateForLibrary(LibraryElement library, BuildStep buildStep) async {
//   final generatedOutputs = await _generate(library, _generators, buildStep).toList();
//
//   // Don't output useless files.
//   //
//   // NOTE: It is important to do this check _before_ checking for valid
//   // library/part definitions because users expect some files to be skipped
//   // therefore they do not have "library".
//   if (generatedOutputs.isEmpty) return;
//   final outputId = buildStep.allowedOutputs.first;
//   final contentBuffer = StringBuffer();
//
//   if (_header.isNotEmpty) {
//     contentBuffer.writeln(_header);
//   }
//
//   if (!_isLibraryBuilder) {
//     final asset = buildStep.inputId;
//     final partOfUri = uriOfPartial(library, asset, outputId);
//     contentBuffer.writeln();
//
//     if (this is PartBuilder) {
//       contentBuffer
//         ..write(languageOverrideForLibrary(library))
//         ..writeln('part of \'$partOfUri\';');
//       final part = computePartUrl(buildStep.inputId, outputId);
//
//       final libraryUnit = await buildStep.resolver.compilationUnitFor(buildStep.inputId);
//       final hasLibraryPartDirectiveWithOutputUri = hasExpectedPartDirective(libraryUnit, part);
//       if (!hasLibraryPartDirectiveWithOutputUri) {
//         // log.warning(
//         //   '$part must be included as a part directive in '
//         //   'the input library with:\n    part \'$part\';',
//         // );
//         return;
//       }
//     } else {
//       assert(this is SharedPartBuilder);
//       // For shared-part builders, `part` statements will be checked by the
//       // combining build step.
//     }
//   }
//
//   for (var item in generatedOutputs) {
//     if (_writeDescriptions) {
//       contentBuffer
//         ..writeln()
//         ..writeln(_headerLine)
//         ..writeAll(LineSplitter.split(item.generatorDescription).map((line) => '// $line\n'))
//         ..writeln(_headerLine)
//         ..writeln();
//     }
//
//     contentBuffer.writeln(item.output);
//   }
//
//   var genPartContent = contentBuffer.toString();
//
//   try {
//     genPartContent = formatOutput(genPartContent);
//   } catch (e, stack) {
//     log.severe(
//       '''
// An error `${e.runtimeType}` occurred while formatting the generated source for
//   `${library.identifier}`
// which was output to
//   `${outputId.path}`.
// This may indicate an issue in the generator, the input source code, or in the
// source formatter.''',
//       e,
//       stack,
//     );
//   }
//
//   await buildStep.writeAsString(outputId, genPartContent);
// }
