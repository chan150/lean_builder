part of 'element.dart';

abstract class ElementAnnotation {
  String get name;

  Constant get constant;

  TypeRef get type;
}

class ElementAnnotationImpl implements ElementAnnotation {
  @override
  final String name;

  @override
  Constant get constant => _constValue ??= _constantValueCompute() ?? Constant.invalid;

  Constant? _constValue;

  final ConstantValueCompute _constantValueCompute;

  @override
  final TypeRef type;

  ElementAnnotationImpl({required this.name, required this.type, required ConstantValueCompute constantValueCompute})
    : _constantValueCompute = constantValueCompute;
}
