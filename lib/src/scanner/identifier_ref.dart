import 'package:code_genie/src/scanner/scan_results.dart';

class IdentifierSrc {
  IdentifierSrc({required this.identifier, required this.srcId, required this.providerId, required this.type});

  final String identifier;
  final String srcId;
  final String providerId;
  final TopLevelIdentifierType type;

  @override
  String toString() {
    return 'IdentifierReference{identifier: $identifier, srcHash: $srcId, providerHash: $providerId}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is IdentifierSrc && other.identifier == identifier && other.srcId == srcId && type == other.type;
  }

  @override
  int get hashCode {
    return identifier.hashCode ^ srcId.hashCode ^ type.hashCode;
  }
}
