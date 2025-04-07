part of 'element.dart';

abstract class ElementAnnotation {
  String get name;
  Element get annotationElement;
}

class ElementAnnotationImpl implements ElementAnnotation {
  @override
  final String name;

  @override
  final Element annotationElement;

  ElementAnnotationImpl(this.name, this.annotationElement);
}
