import 'package:analyzer/dart/ast/visitor.dart';
import 'package:code_genie/src/resolvers/element/element.dart';

mixin ElementStack on UnifyingAstVisitor<void> {
  final List<Element> _elementStack = [];

  Element get _currentElement => _elementStack.last;

  T currentElementAs<T extends Element>() {
    assert(_currentElement is T, 'Current element is not of type $T');
    return _currentElement as T;
  }

  void pushElement(Element element) {
    _elementStack.add(element);
  }

  Element? popElement() {
    if (_elementStack.length > 1) {
      // Always keep library element
      return _elementStack.removeLast();
    }
    return null;
  }

  void visitElementScoped(Element element, void Function() callback) {
    assert(_elementStack.isNotEmpty, 'Element stack is empty');
    if (element == _currentElement) {
      callback();
    }
    pushElement(element);
    callback();
    popElement();
  }
}
