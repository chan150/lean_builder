import 'package:lean_builder/src/resolvers/file_asset.dart';

class BuildResult {
  final Map<Asset, Set<Uri>> outputs;
  final List<FieldAsset> fieldAssets;

  BuildResult(this.outputs, this.fieldAssets);

  factory BuildResult.empty() {
    return BuildResult({}, []);
  }

  @override
  String toString() {
    final outputCount = outputs.length;
    final failedCount = fieldAssets.length;
    return 'BuildResult(outputs: $outputCount, fieldAssets: $failedCount)';
  }

  void append(BuildResult other) {
    for (final entry in other.outputs.entries) {
      outputs.putIfAbsent(entry.key, () => {}).addAll(entry.value);
    }
    fieldAssets.addAll(other.fieldAssets);
  }
}

class FieldAsset {
  final Asset asset;
  final Object? error;

  FieldAsset(this.asset, this.error);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FieldAsset && runtimeType == other.runtimeType && asset == other.asset && error == other.error;

  @override
  int get hashCode => asset.hashCode ^ error.hashCode;
}
