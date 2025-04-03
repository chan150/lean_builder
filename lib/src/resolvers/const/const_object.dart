import 'package:code_genie/src/resolvers/file_asset.dart';

abstract class ConstValue {}

abstract class ConstObject extends ConstValue {
  Map<String, dynamic> get props;

  String? getString(String key);

  int? getInt(String key);

  double? getDouble(String key);

  bool? getBool(String key);
}
