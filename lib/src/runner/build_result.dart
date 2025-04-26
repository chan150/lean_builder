import 'package:lean_builder/src/asset/asset.dart';

import '../graph/isolate_symbols_scanner.dart';

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
  final Object? error;

  FieldAsset(this.asset, this.error);

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
