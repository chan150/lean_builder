import 'package:lean_builder/src/asset/asset.dart';
import 'package:lean_builder/src/graph/asset_scan_manager.dart';

class BuildResult {
  final Map<Asset, Set<Uri>> outputs;
  final List<FieldAsset> fieldAssets;

  BuildResult(this.outputs, this.fieldAssets);

  @override
  String toString() {
    final outputCount = outputs.length;
    final failedCount = fieldAssets.length;
    return 'BuildResult(outputs: $outputCount, fieldAssets: $failedCount)';
  }
}

class FieldAsset {
  final Asset asset;
  final Object error;
  final StackTrace? stackTrace;

  FieldAsset(this.asset, this.error, this.stackTrace);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FieldAsset && runtimeType == other.runtimeType && asset == other.asset && error == other.error;

  @override
  int get hashCode => asset.hashCode ^ error.hashCode;
}

class PhaseResult {
  final List<ProcessableAsset> outputs;

  final List<FieldAsset> failedAssets;

  bool get hasErrors => failedAssets.isNotEmpty;

  PhaseResult(this.outputs, this.failedAssets);
}

class MultiFieldAssetsException implements Exception {
  final List<FieldAsset> assets;

  MultiFieldAssetsException(this.assets);
}
