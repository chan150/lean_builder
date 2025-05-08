import 'dart:async' show Zone, FutureOr;
import 'dart:convert' show LineSplitter;

import 'package:dart_style/dart_style.dart';
import 'package:lean_builder/src/asset/package_file_resolver.dart';
import 'package:lean_builder/src/element/element.dart';
import 'package:lean_builder/src/logger.dart';
import 'package:lean_builder/src/resolvers/resolver.dart';
import 'package:path/path.dart' as p;
import 'build_step.dart';
import 'builder.dart';
import 'generator/generated_output.dart';
import 'generator/generator.dart';

/// Default header for generated files.
const String defaultFileHeader = '// GENERATED CODE - DO NOT MODIFY BY HAND';

/// Flag indicating whether the code is running in development mode.
final bool _isDevMode = Zone.current[#isDevMode] == true;

/// Default formatter function for generated Dart code.
///
/// Uses the latest language version supported by the formatter.
String _defaultFormatOutput(String code) => DartFormatter(
  languageVersion: DartFormatter.latestLanguageVersion,
).format(code);

/// Line of asterisks used as a separator in generated files.
final String _headerLine = '// '.padRight(77, '*');

/// {@template builder_impl.builder}
/// A [Builder] wrapping one or more [Generator]s.
///
/// This abstract class provides the base functionality for different types of builders
/// that can run one or more generators against Dart libraries.
/// {@endtemplate}
abstract class _Builder extends Builder {
  /// {@template builder_impl.format_output}
  /// Function that determines how the generated code is formatted.
  ///
  /// The `languageVersion` is the version to parse the file with, but it may be
  /// overridden using a language version comment in the file.
  /// {@endtemplate}
  final String Function(String code) formatOutput;

  /// {@template builder_impl.generators}
  /// The generators run for each targeted library.
  /// {@endtemplate}
  final List<Generator> _generators;

  /// {@template builder_impl.header}
  /// The header text to include at the top of each generated file.
  /// {@endtemplate}
  final String _header;

  /// {@template builder_impl.write_descriptions}
  /// Whether to include or emit the generator descriptions in comments.
  /// {@endtemplate}
  final bool _writeDescriptions;

  /// {@template builder_impl.allow_syntax_errors}
  /// Whether to continue processing even when syntax errors are present in input libraries.
  /// {@endtemplate}
  final bool allowSyntaxErrors;

  @override
  Set<String> outputExtensions;

  /// {@template builder_impl.constructor}
  /// Creates a new builder that wraps the provided generators.
  ///
  /// @param _generators The list of generators to run
  /// @param formatOutput Function to format the generated code
  /// @param outputExtensions File extensions that this builder will create
  /// @param header Optional header text for generated files
  /// @param writeDescriptions Whether to include generator descriptions in comments
  /// @param allowSyntaxErrors Whether to process files with syntax errors
  /// @param options Additional configuration options
  /// {@endtemplate}
  _Builder(
    this._generators, {
    required this.formatOutput,
    this.outputExtensions = const <String>{'.g.dart'},
    String? header,
    bool? writeDescriptions,
    this.allowSyntaxErrors = false,
    BuilderOptions? options,
  }) : _writeDescriptions = writeDescriptions ?? true,
       _header = (header ?? defaultFileHeader).trim() {
    if (outputExtensions.isEmpty) {
      throw ArgumentError('Output extensions must not be empty.');
    }
    for (final String ext in outputExtensions) {
      if (ext.isEmpty || !ext.startsWith('.')) {
        throw ArgumentError('Output extensions must be in the format of .*');
      }
      if (ext == '.dart') {
        throw ArgumentError('Output extensions must not be .dart');
      }
    }
  }

  @override
  bool shouldBuildFor(BuildCandidate candidate) {
    return candidate.isDartSource && candidate.hasTopLevelMetadata;
  }

  @override
  Future<void> build(BuildStep buildStep) async {
    final Resolver resolver = buildStep.resolver;
    if (!resolver.isLibrary(buildStep.asset)) {
      return;
    }
    final LibraryElement library = resolver.resolveLibrary(
      buildStep.asset,
      allowSyntaxErrors: allowSyntaxErrors,
      preResolveTopLevelMetadata: true,
    );
    await generateForLibrary(library, buildStep);
  }

  /// {@template builder_impl.generate}
  /// Runs each generator on the provided library and yields the outputs.
  ///
  /// Logs progress information and filters out empty or null outputs.
  ///
  /// @param library The library element to generate code for
  /// @param generators The list of generators to run
  /// @param buildStep The build step providing context for generation
  /// @return A stream of generated outputs from each generator
  /// {@endtemplate}
  Stream<GeneratedOutput> _generate(
    LibraryElement library,
    List<Generator> generators,
    BuildStep buildStep,
  ) async* {
    for (int i = 0; i < generators.length; i++) {
      final Generator gen = generators[i];
      String msg = 'Running $gen';
      if (generators.length > 1) {
        msg = '$msg - ${i + 1} of ${generators.length}';
      }
      Logger.fine(msg);
      String? createdUnit = await gen.generate(library, buildStep);

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

  /// {@template builder_impl.generate_for_library}
  /// Generates code for the given library using all registered generators.
  ///
  /// Collects outputs from all generators, formats them, and writes them
  /// to the appropriate output file with proper headers and separators.
  ///
  /// @param library The library to generate code for
  /// @param buildStep The build step providing context for generation
  /// {@endtemplate}
  Future<void> generateForLibrary(
    LibraryElement library,
    BuildStep buildStep,
  ) async {
    final List<GeneratedOutput> generatedOutputs =
        await _generate(library, _generators, buildStep).toList();
    if (generatedOutputs.isEmpty) return;

    final StringBuffer contentBuffer = StringBuffer();
    if (_header.isNotEmpty) {
      contentBuffer.writeln(_header);
    }

    final String extension = buildStep.allowedExtensions.first;
    for (GeneratedOutput item in generatedOutputs) {
      if (_writeDescriptions) {
        contentBuffer
          ..writeln()
          ..writeln(_headerLine)
          ..writeAll(
            LineSplitter.split(
              item.generatorDescription,
            ).map((String line) => '// $line\n'),
          )
          ..writeln(_headerLine)
          ..writeln();
      }

      contentBuffer.writeln(item.output);
    }

    await writeOutput(buildStep, contentBuffer.toString(), extension);
  }

  /// {@template builder_impl.write_output}
  /// Formats and writes the generated content to the output file.
  ///
  /// Attempts to format the content using the configured formatter.
  /// If formatting fails, logs an error but proceeds with writing the unformatted content.
  /// In development mode, allows syntax errors in the generated code.
  ///
  /// @param buildStep The build step to use for writing
  /// @param content The content to format and write
  /// @param extension The file extension to use for the output
  /// {@endtemplate}
  FutureOr<void> writeOutput(
    BuildStep buildStep,
    String content,
    String extension,
  ) {
    try {
      content = formatOutput(content);
    } catch (e, stack) {
      final PackageFileResolver fileResolver = buildStep.resolver.fileResolver;
      final Uri output = buildStep.asset.uriWithExtension(extension);
      Logger.error(
        '''An error `${e.runtimeType}` occurred while formatting the generated source for `${buildStep.asset.shortUri}`
which was output to `${fileResolver.toShortUri(output)}`.
This may indicate an issue in the generator, the input source code, or in the source formatter.''',
        stackTrace: stack,
      );
      // allow syntax errors in the generated code in dev mode
      if (!_isDevMode) return Future<void>.value(null);
    }

    return buildStep.writeAsString(content, extension: extension);
  }

  @override
  String toString() =>
      'Generating $outputExtensions: ${_generators.join(', ')}';
}

/// {@template library_builder}
/// A specialized [Builder] that generates Dart library files.
///
/// This builder creates standalone Dart files that aren't part files.
/// Each output file will include a header and can include generator descriptions.
/// {@endtemplate}
class LibraryBuilder extends _Builder {
  /// {@template library_builder.constructor}
  /// Creates a builder that generates standalone Dart library files.
  ///
  /// @param generator The generator to run
  /// @param formatOutput Function to format the generated code
  /// @param outputExtensions File extensions that this builder will create
  /// @param writeDescriptions Whether to include generator descriptions in comments
  /// @param header Optional header text for generated files
  /// @param allowSyntaxErrors Whether to process files with syntax errors
  /// @param options Additional configuration options
  /// {@endtemplate}
  LibraryBuilder(
    Generator generator, {
    super.formatOutput = _defaultFormatOutput,
    required super.outputExtensions,
    super.writeDescriptions,
    super.header,
    super.allowSyntaxErrors,
    super.options,
  }) : super(<Generator>[generator]) {
    for (final String ext in outputExtensions) {
      if (ext == SharedPartBuilder.extension) {
        throw ArgumentError(
          'The LibraryBuilder cannot be used with the shared part extension',
        );
      }
      if (!ext.endsWith('.dart')) {
        throw ArgumentError(
          'LibraryBuilder output extensions must end with .dart',
        );
      }
    }
  }
}

/// {@template shared_part_builder}
/// A specialized [Builder] that generates Dart part files that can be shared
/// by multiple generators.
///
/// This builder creates part files that must be included in the original library
/// via a part directive. It can run multiple generators and combine their output
/// into a single file.
/// {@endtemplate}
class SharedPartBuilder extends _Builder {
  /// The extension used for shared part files.
  static const String extension = '.g.dart';

  /// {@template shared_part_builder.constructor}
  /// Creates a builder that generates shared part files.
  ///
  /// @param _generators The list of generators to run
  /// @param formatOutput Function to format the generated code
  /// @param allowSyntaxErrors Whether to process files with syntax errors
  /// @param writeDescriptions Whether to include generator descriptions in comments
  /// @param options Additional configuration options
  /// {@endtemplate}
  SharedPartBuilder(
    super._generators, {
    super.formatOutput = _defaultFormatOutput,
    super.allowSyntaxErrors,
    super.writeDescriptions,
    super.options,
  }) : super(outputExtensions: <String>{extension}, header: '');

  @override
  FutureOr<void> writeOutput(
    BuildStep buildStep,
    String content,
    String extension,
  ) {
    if (outputExtensions.length != 1 ||
        outputExtensions.first != SharedPartBuilder.extension) {
      throw ArgumentError(
        'The output extension must be ${SharedPartBuilder.extension} '
        'but was ${outputExtensions.join(', ')}',
      );
    }

    if (extension != SharedPartBuilder.extension) {
      throw ArgumentError('The Shared extension must be $extension');
    }
    if (!buildStep.hasValidPartDirectiveFor(extension)) {
      final Uri outputUri = buildStep.asset.uriWithExtension(extension);
      final String part = p.relative(
        outputUri.path,
        from: p.dirname(buildStep.asset.uri.path),
      );
      throw ArgumentError(
        'The input library must have a part directive for the generated part\n'
        'file. Please add a part directive (part \'$part\';) to the input library ${buildStep.asset.shortUri}',
      );
    }
    return super.writeOutput(buildStep, content, extension);
  }
}
