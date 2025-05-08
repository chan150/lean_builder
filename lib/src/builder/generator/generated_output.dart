import 'generator.dart';

/// {@template generated_output}
/// Represents the output produced by a generator.
///
/// This class stores both the generated code and information about
/// which generator produced it, allowing the build system to track
/// and properly format the output.
/// {@endtemplate}
class GeneratedOutput {
  /// {@template generated_output.output}
  /// The generated code content.
  ///
  /// This must be non-empty and pre-trimmed.
  /// {@endtemplate}
  final String output;

  /// {@template generated_output.generator_description}
  /// A human-readable description of the generator that produced this output.
  ///
  /// Used for comments in the generated code to identify the source generator.
  /// {@endtemplate}
  final String generatorDescription;

  /// {@template generated_output.constructor}
  /// Creates a new output instance from a generator and its output content.
  ///
  /// The output must be non-empty and pre-trimmed.
  /// The generator description is automatically derived from the generator.
  ///
  /// @param generator The generator that produced this output
  /// @param output The generated code content
  /// {@endtemplate}
  GeneratedOutput(Generator generator, this.output)
    : assert(output.isNotEmpty),
      // assuming length check is cheaper than simple string equality
      assert(output.length == output.trim().length),
      generatorDescription = _toString(generator);

  static String _toString(Generator generator) {
    final String output = generator.toString();
    if (output.endsWith('Generator')) {
      return output;
    }
    return 'Generator: $output';
  }
}
