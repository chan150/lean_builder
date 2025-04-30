import 'package:lean_builder/element.dart';

class InvalidGenerationSourceError implements Exception {
  final String message;
  final Element? element;

  InvalidGenerationSourceError(this.message, {this.element});

  @override
  String toString() {
    return 'InvalidGenerationSourceError: $message';
  }
}
