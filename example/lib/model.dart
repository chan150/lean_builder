import 'package:example/src/annotations.dart';

part 'model.g.dart';

@Serializable('Hello')
class Model {
  final String name;
  final int age = 123;
  final String? email;
  final String? phone;
  final double? address;
  final bool? isActive;

  Model(this.name, this.email, this.phone, this.address, this.isActive);

  /// hello
}
