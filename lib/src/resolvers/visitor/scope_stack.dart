import 'package:analyzer/dart/ast/visitor.dart';
import 'package:code_genie/src/resolvers/type/type.dart';
import 'package:code_genie/src/resolvers/element/element.dart';

mixin ScopeStack on UnifyingAstVisitor<void> {
  final List<Element> _elementStack = [];
  final List<DartType> _typeStack = [];

  Element get _currentElement => _elementStack.last;

  DartType? get _currentType => _typeStack.lastOrNull;

  T currentElementAs<T extends Element>() {
    assert(_currentElement is T, 'Current element is not of type $T');
    return _currentElement as T;
  }

  T? currentTypeAs<T extends DartType>() {
    if (_currentType == null) {
      return null;
    }
    assert(_currentType is T, 'Current type is not of type $T');
    return _currentType as T;
  }

  // Push/pop context methods
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

  void pushType(DartType type) {
    _typeStack.add(type);
  }

  DartType? popType() {
    if (_typeStack.isNotEmpty) {
      return _typeStack.removeLast();
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

  void visitTypeScoped(DartType type, void Function() callback) {
    if (type == _currentType) {
      callback();
    }
    pushType(type);
    callback();
    popType();
  }
}
