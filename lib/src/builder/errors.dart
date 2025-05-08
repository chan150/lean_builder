import 'package:analyzer/dart/ast/ast.dart' show AstNode;
import 'package:lean_builder/element.dart' show Element, FieldElement;
import 'package:lean_builder/src/asset/asset.dart';
import 'package:source_span/source_span.dart' show SourceFile, SourceSpan;

/// A description of a problem in the source input to code generation.
///
/// May be thrown by generators during [Generator.generate] to communicate a
/// problem to the codegen user.
class InvalidGenerationSourceError implements Exception {
  /// What failure occurred.
  final String message;

  /// What could have been changed in the source code to resolve this error.
  ///
  /// May be an empty string if unknown.
  final String todo;

  /// The code element associated with this error.
  ///
  /// May be `null` if the error had no associated element, or if the location
  /// was passed with [node].
  final Element? element;

  /// The AST Node associated with this error.
  ///
  /// May be `null` if the error has no associated node in the input source
  /// code, or if the location was passed with [element].
  final AstNode? node;

  /// Creates an [InvalidGenerationSourceError] with the given arguments.
  InvalidGenerationSourceError(this.message, {this.todo = '', this.element, this.node});

  @override
  String toString() {
    final StringBuffer buffer = StringBuffer(message);

    if (element case final Element element?) {
      try {
        final SourceSpan span = spanForElement(element);
        buffer
          ..writeln()
          ..writeln(span.start.toolString)
          ..write(span.highlight());
      } catch (e) {
        buffer
          ..writeln()
          ..writeln('Cause: ${element.runtimeType} : ${element.name}');
      }
    }

    if (node case final AstNode node?) {
      try {
        final SourceSpan span = spanForNode(node);
        buffer
          ..writeln()
          ..writeln(span.start.toolString)
          ..write(span.highlight());
      } catch (_) {
        buffer
          ..writeln()
          ..writeln('Cause: $node');
      }
    }

    return buffer.toString();
  }
}

/// Returns a source span that spans the location where [element] is defined.
SourceSpan spanForElement(Element element) {
  final Asset src = element.library.src;
  final String source = src.readAsStringSync();
  final SourceFile file = SourceFile.fromString(source, url: src.uri);
  if (element.nameOffset < 0) {
    if (element is FieldElement) {
      if (element.getter != null) {
        return spanForElement(element.getter!);
      }

      if (element.setter != null) {
        return spanForElement(element.setter!);
      }
    }
  }

  final int nameOffset = element.nameOffset;
  return file.span(nameOffset, nameOffset + element.nameLength);
}

/// Returns a source span that spans the location where [node] is written.
SourceSpan spanForNode(AstNode node) {
  final SourceFile file = SourceFile.fromString(node.toSource());
  return file.span(node.offset, node.offset + node.length);
}
