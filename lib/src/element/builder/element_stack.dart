import 'package:analyzer/dart/ast/ast.dart' show AstVisitor;
import 'package:lean_builder/src/element/element.dart' show Element, ElementImpl, LibraryElementImpl, LibraryElement;

/// {@template element_stack}
/// A mixin that provides element stack management functionality for AST visitors.
///
/// This mixin allows tracking the current element being processed during AST traversal,
/// maintaining a stack of elements that represents the nesting of elements in the code.
/// It provides methods for pushing, popping, and accessing elements in the stack.
/// {@endtemplate}
mixin ElementStack<E> on AstVisitor<E> {
  /// The stack of elements being processed, with the most recently entered element at the end.
  final List<Element> _elementStack = <Element>[];

  /// {@template element_stack.current_element}
  /// Returns the element at the top of the stack (the most recently entered element).
  ///
  /// This represents the "current" element being processed during AST traversal.
  /// {@endtemplate}
  Element get _currentElement => _elementStack.last;

  /// {@template element_stack.current_element_as}
  /// Returns the current element cast to the specified type.
  ///
  /// Asserts that the current element is of the expected type.
  /// Useful for safely accessing type-specific functionality of the current element.
  ///
  /// @return The current element cast to type T
  /// @throws AssertionError if the current element is not of type T
  /// {@endtemplate}
  T currentElementAs<T extends Element>() {
    assert(
      _currentElement is T,
      'Current element is not of type $T, it is ${_currentElement.runtimeType}\n${StackTrace.current}',
    );
    return _currentElement as T;
  }

  /// {@template element_stack.current_library}
  /// Returns the library element that contains the current element.
  ///
  /// Asserts that the element stack is not empty.
  ///
  /// @return The library element containing the current element
  /// @throws AssertionError if the element stack is empty
  /// {@endtemplate}
  LibraryElementImpl currentLibrary() {
    assert(_elementStack.isNotEmpty, 'Element stack is empty');
    return _currentElement.library as LibraryElementImpl;
  }

  /// {@template element_stack.push_element}
  /// Pushes an element onto the stack, making it the current element.
  ///
  /// @param element The element to push onto the stack
  /// {@endtemplate}
  void pushElement(Element element) {
    _elementStack.add(element);
  }

  /// {@template element_stack.pop_element}
  /// Pops an element from the stack, removing it as the current element.
  ///
  /// Does not pop the last element (typically the library element) to ensure
  /// the stack is never completely empty.
  ///
  /// @return The element that was popped, or null if the stack has only one element
  /// {@endtemplate}
  Element? popElement() {
    if (_elementStack.length > 1) {
      // Always keep library element
      return _elementStack.removeLast();
    }
    return null;
  }

  /// {@template element_stack.visit_element_scoped}
  /// Executes a callback function with the specified element as the current element.
  ///
  /// Pushes the element onto the stack, executes the callback, and then pops the element.
  /// If the specified element is already the current element, simply executes the callback.
  ///
  /// @param element The element to make current during callback execution
  /// @param callback The function to execute with the specified element as current
  /// @return The result of the callback
  /// @throws AssertionError if the element stack is empty
  /// {@endtemplate}
  R? visitElementScoped<R>(Element element, R? Function() callback) {
    assert(_elementStack.isNotEmpty, 'Element stack is empty');
    if (element == _currentElement) {
      return callback();
    }
    pushElement(element);
    final R? result = callback();
    popElement();
    return result;
  }

  /// {@template element_stack.visit_with_holder}
  /// Executes a callback with a temporary holder element on the stack.
  ///
  /// Creates a new holder element associated with the given library, pushes it onto
  /// the stack, executes the callback with the holder as parameter, and pops it afterwards.
  ///
  /// @param library The library to associate with the holder element
  /// @param callback The function to execute with the holder element
  /// @return The result of the callback
  /// @throws AssertionError if the element stack is empty
  /// {@endtemplate}
  R? visitWithHolder<R>(LibraryElement library, R Function(ElementImpl element) callback) {
    assert(_elementStack.isNotEmpty, 'Element stack is empty');
    final _HolderElement holder = _HolderElement(library);
    pushElement(holder);
    final R? result = callback(holder);
    popElement();
    return result;
  }
}

/// {@template holder_element}
/// A temporary element that serves as a placeholder in the element stack.
///
/// Used to provide a library context for operations that don't naturally have
/// an associated element but need library context for resolution.
/// {@endtemplate}
class _HolderElement extends ElementImpl {
  /// {@template holder_element.constructor}
  /// Creates a new holder element associated with the specified library.
  ///
  /// @param library The library that provides context for this holder
  /// {@endtemplate}
  _HolderElement(this.library);

  @override
  Null get enclosingElement => null;

  @override
  final LibraryElement library;

  @override
  String get name => '';
}
