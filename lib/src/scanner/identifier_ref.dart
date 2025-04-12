import 'package:code_genie/src/resolvers/file_asset.dart';
import 'package:code_genie/src/scanner/scan_results.dart';

class IdentifierLocation {
  IdentifierLocation({
    required this.identifier,
    required this.srcId,
    required this.providerId,
    required this.type,
    required this.srcUri,
    required this.importingLibrary,
  });

  final String identifier;
  final String srcId;
  final Uri srcUri;
  final String providerId;
  final TopLevelIdentifierType type;
  final AssetSrc importingLibrary;
  @override
  String toString() {
    return 'IdentifierLocation{identifier: $identifier, srcId: $srcId, providerId: $providerId}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is IdentifierLocation &&
        other.identifier == identifier &&
        other.providerId == providerId &&
        other.srcId == srcId &&
        type == other.type &&
        other.srcUri == srcUri;
  }

  @override
  int get hashCode {
    return identifier.hashCode ^
        srcId.hashCode ^
        type.hashCode ^
        srcUri.hashCode ^
        providerId.hashCode ^
        importingLibrary.hashCode;
  }
}
