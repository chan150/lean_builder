import 'dart:typed_data';

import 'package:lean_builder/src/asset/asset.dart';
import 'package:lean_builder/src/graph/scan_results.dart';
import 'package:xxh3/xxh3.dart';

class DeclarationRef {
  DeclarationRef({
    required this.identifier,
    required this.srcId,
    required this.providerId,
    required this.type,
    required this.srcUri,
    this.importingLibrary,
    this.importPrefix,
  });

  final String identifier;
  final String srcId;
  final Uri srcUri;
  final String providerId;
  final TopLevelIdentifierType type;
  final Asset? importingLibrary;
  final String? importPrefix;

  factory DeclarationRef.from(String name, String uri, TopLevelIdentifierType type) {
    return DeclarationRef(
      identifier: name,
      srcId: xxh3String(Uint8List.fromList(uri.codeUnits)),
      providerId: uri,
      type: type,
      srcUri: Uri.parse(uri),
    );
  }

  @override
  String toString() {
    return 'IdentifierLocation{identifier: $identifier, srcId: $srcId, providerId: $providerId}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is DeclarationRef &&
        other.identifier == identifier &&
        other.providerId == providerId &&
        other.importPrefix == importPrefix &&
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
        importPrefix.hashCode ^
        importingLibrary.hashCode;
  }
}
