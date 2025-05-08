import 'dart:typed_data' show Uint8List;

import 'package:lean_builder/src/asset/asset.dart';
import 'package:lean_builder/src/graph/scan_results.dart';
import 'package:xxh3/xxh3.dart' show xxh3String;

/// {@template declaration_ref}
/// Represents a reference to a declaration in Dart code.
///
/// A [DeclarationRef] provides detailed information about where an identifier is declared,
/// including:
/// - The identifier name
/// - The source file ID where it's declared
/// - The URI of the source file
/// - The provider ID (which may differ from source ID for re-exports)
/// - The type of reference (class, function, variable, etc.)
/// - Information about imports (optional)
///
/// This class is crucial for resolving references across files and packages,
/// especially when dealing with imports, exports, and re-exports.
/// {@endtemplate}
class DeclarationRef {
  /// {@macro declaration_ref}
  DeclarationRef({
    required this.identifier,
    required this.srcId,
    required this.providerId,
    required this.type,
    required this.srcUri,
    this.importingLibrary,
    this.importPrefix,
  });

  /// The name of the declared identifier
  final String identifier;

  /// The unique ID of the source file where this declaration is defined
  final String srcId;

  /// The URI of the source file where this declaration is defined
  final Uri srcUri;

  /// The ID of the library that provides this declaration
  ///
  /// This may differ from [srcId] when the declaration is re-exported
  /// through another library.
  final String providerId;

  /// The type of reference (class, function, variable, etc.)
  final ReferenceType type;

  /// The library that is importing this declaration, if applicable
  final Asset? importingLibrary;

  /// The import prefix used to import this declaration, if any
  ///
  /// For example, in `import 'package:foo/bar.dart' as foo;`,
  /// the import prefix would be "foo".
  final String? importPrefix;

  /// {@template declaration_ref.from}
  /// Creates a [DeclarationRef] from a name, URI string, and reference type.
  ///
  /// This factory method:
  /// 1. Computes a hash of the URI to create the source ID
  /// 2. Uses the URI directly as the provider ID
  /// 3. Creates a [Uri] object from the URI string
  ///
  /// [name] The identifier name
  /// [uri] The URI string where the declaration is defined
  /// [type] The type of reference
  /// {@endtemplate}
  factory DeclarationRef.from(String name, String uri, ReferenceType type) {
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
