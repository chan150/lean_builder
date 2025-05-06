import 'package:lean_builder/src/asset/asset.dart';

class BuildResult {
  final Map<Asset, Set<Uri>> outputs;
  final List<FailedAsset> fieldAssets;

  BuildResult(this.outputs, this.fieldAssets);

  @override
  String toString() {
    final outputCount = outputs.length;
    final failedCount = fieldAssets.length;
    return 'BuildResult(outputs: $outputCount, fieldAssets: $failedCount)';
  }
}

class FailedAsset {
  final Asset asset;
  final Object error;
  final StackTrace? stackTrace;

  FailedAsset(this.asset, this.error, this.stackTrace);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FailedAsset && runtimeType == other.runtimeType && asset == other.asset && error == other.error;

  @override
  int get hashCode => asset.hashCode ^ error.hashCode;
}

class PhaseResult {
  final List<Uri> outputs;

  final List<FailedAsset> failedAssets;

  bool get hasErrors => failedAssets.isNotEmpty;

  PhaseResult(this.outputs, this.failedAssets);
}

class MultiFieldAssetsException implements Exception {
  final List<FailedAsset> assets;

  MultiFieldAssetsException(this.assets);
}
