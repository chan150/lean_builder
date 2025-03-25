import 'package:code_genie/src/scanner/scan_results.dart';

class IdentifierRef {
  IdentifierRef({
    required this.identifier,
    required this.srcId,
    required this.providerId,
    required this.srcUri,
    required this.providerUri,
    required this.type,
  });

  final String identifier;
  final String srcId;
  final String providerId;
  final Uri srcUri;
  final Uri providerUri;
  final IdentifierType type;

  @override
  String toString() {
    return 'IdentifierReference{identifier: $identifier, srcHash: $srcId, providerHash: $providerId}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is IdentifierRef &&
        other.identifier == identifier &&
        other.srcId == srcId &&
        other.srcUri == srcUri &&
        type == other.type;
  }

  @override
  int get hashCode {
    return identifier.hashCode ^ srcId.hashCode ^ srcUri.hashCode ^ type.hashCode;
  }
}
