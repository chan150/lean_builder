import 'package:lean_builder/runner.dart';
import 'package:lean_builder/src/asset/asset.dart';

class BuildResult {
  final Map<Asset, Set<Uri>> outputs;
  final List<FailedAsset> faildAssets;

  BuildResult(this.outputs, this.faildAssets);

  @override
  String toString() {
    final outputCount = outputs.length;
    final failedCount = faildAssets.length;
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
  final Set<Uri> outputs;
  final Set<Uri> deletedOutputs;
  final List<FailedAsset> failedAssets;

  bool get hasErrors => failedAssets.isNotEmpty;

  PhaseResult({required this.outputs, required this.failedAssets, required this.deletedOutputs});

  bool get containsAnyChanges => outputs.isNotEmpty || deletedOutputs.isNotEmpty;

  bool containsChangesFromBuilder(BuilderEntry entry) {
    bool didAnyChange = false;
    for (final ext in entry.outputExtensions) {
      if (outputs.any((e) => e.path.endsWith(ext))) {
        didAnyChange = true;
        break;
      }
      if (deletedOutputs.any((e) => e.path.endsWith(ext))) {
        didAnyChange = true;
        break;
      }
    }
    return didAnyChange;
  }
}

class MultiFailedAssetsException implements Exception {
  final List<FailedAsset> assets;

  MultiFailedAssetsException(this.assets);
}
