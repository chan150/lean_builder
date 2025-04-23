import 'package:lean_builder/test/annotation.dart';
import 'test3.dart';

part 'test.g.dart';

abstract base class X {}

@Genix('Hello223323233342we323')
class AnnotatedClass {
  AnnotatedClass(this.field1);
  final FieldType field1;
  final AnnotatedClass field2 = AnnotatedClass(FieldType());
  final String field3 = 'Hello223323233342we323';
  final int field4 = 1;
  final double field5 = 1.0;
  final bool field6 = true;
  final List<String> field7 = ['Hello223323233342we323'];
  final List<int> field8 = [1];
  final List<double> field9 = [1.0];
}
