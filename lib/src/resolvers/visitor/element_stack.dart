import 'package:analyzer/dart/ast/ast.dart';
import 'package:lean_builder/src/resolvers/element/element.dart';

mixin ElementStack<E> on AstVisitor<E> {
  final List<Element> _elementStack = [];

  Element get _currentElement => _elementStack.last;

  T currentElementAs<T extends Element>() {
    assert(
      _currentElement is T,
      'Current element is not of type $T, it is ${_currentElement.runtimeType}\n${StackTrace.current}',
    );
    return _currentElement as T;
  }

  LibraryElementImpl currentLibrary() {
    assert(_elementStack.isNotEmpty, 'Element stack is empty');
    return _currentElement.library as LibraryElementImpl;
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

  R? visitElementScoped<R>(Element element, R? Function() callback) {
    assert(_elementStack.isNotEmpty, 'Element stack is empty');
    if (element == _currentElement) {
      return callback();
    }
    pushElement(element);
    final result = callback();
    popElement();
    return result;
  }
}
