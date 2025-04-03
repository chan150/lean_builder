// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:code_genie/src/resolvers/element/element.dart';
import 'package:code_genie/src/resolvers/element_resolver.dart';
import 'package:code_genie/src/resolvers/visitor/element_builder_visitor.dart';

class ConstantEvaluator extends GeneralizingAstVisitor<Object> {
  /// The value returned for expressions (or non-expression nodes) that are not
  /// compile-time constant expressions.
  static Object notAConstant = Object();

  final ElementResolver _resolver;

  final ElementResolverVisitor _elementResolverVisitor;

  final LibraryElement _library;

  ConstantEvaluator(this._resolver, this._library, this._elementResolverVisitor);

  Object? evaluate(AstNode node) {
    return node.accept(this);
  }

  @override
  Object? visitAdjacentStrings(AdjacentStrings node) {
    StringBuffer buffer = StringBuffer();
    for (StringLiteral string in node.strings) {
      var value = string.accept(this);
      if (identical(value, notAConstant)) {
        return value;
      }
      buffer.write(value);
    }
    return buffer.toString();
  }

  @override
  Object? visitBinaryExpression(BinaryExpression node) {
    var leftOperand = node.leftOperand.accept(this);
    if (identical(leftOperand, notAConstant)) {
      return leftOperand;
    }
    var rightOperand = node.rightOperand.accept(this);
    if (identical(rightOperand, notAConstant)) {
      return rightOperand;
    }
    while (true) {
      if (node.operator.type == TokenType.AMPERSAND) {
        // integer or {@code null}
        if (leftOperand is int && rightOperand is int) {
          return leftOperand & rightOperand;
        }
      } else if (node.operator.type == TokenType.AMPERSAND_AMPERSAND) {
        // boolean or {@code null}
        if (leftOperand is bool && rightOperand is bool) {
          return leftOperand && rightOperand;
        }
      } else if (node.operator.type == TokenType.BANG_EQ) {
        // numeric, string, boolean, or {@code null}
        if (leftOperand is bool && rightOperand is bool) {
          return leftOperand != rightOperand;
        } else if (leftOperand is num && rightOperand is num) {
          return leftOperand != rightOperand;
        } else if (leftOperand is String && rightOperand is String) {
          return leftOperand != rightOperand;
        }
      } else if (node.operator.type == TokenType.BAR) {
        // integer or {@code null}
        if (leftOperand is int && rightOperand is int) {
          return leftOperand | rightOperand;
        }
      } else if (node.operator.type == TokenType.BAR_BAR) {
        // boolean or {@code null}
        if (leftOperand is bool && rightOperand is bool) {
          return leftOperand || rightOperand;
        }
      } else if (node.operator.type == TokenType.CARET) {
        // integer or {@code null}
        if (leftOperand is int && rightOperand is int) {
          return leftOperand ^ rightOperand;
        }
      } else if (node.operator.type == TokenType.EQ_EQ) {
        // numeric, string, boolean, or {@code null}
        if (leftOperand is bool && rightOperand is bool) {
          return leftOperand == rightOperand;
        } else if (leftOperand is num && rightOperand is num) {
          return leftOperand == rightOperand;
        } else if (leftOperand is String && rightOperand is String) {
          return leftOperand == rightOperand;
        }
      } else if (node.operator.type == TokenType.GT) {
        // numeric or {@code null}
        if (leftOperand is num && rightOperand is num) {
          return leftOperand.compareTo(rightOperand) > 0;
        }
      } else if (node.operator.type == TokenType.GT_EQ) {
        // numeric or {@code null}
        if (leftOperand is num && rightOperand is num) {
          return leftOperand.compareTo(rightOperand) >= 0;
        }
      } else if (node.operator.type == TokenType.GT_GT) {
        // integer or {@code null}
        if (leftOperand is int && rightOperand is int) {
          return leftOperand >> rightOperand;
        }
      } else if (node.operator.type == TokenType.GT_GT_GT) {
        if (leftOperand is int && rightOperand is int) {
          // TODO(srawlins): Replace with native VM implementation once stable.
          return rightOperand >= 64 ? 0 : (leftOperand >> rightOperand) & ((1 << (64 - rightOperand)) - 1);
        }
      } else if (node.operator.type == TokenType.LT) {
        // numeric or {@code null}
        if (leftOperand is num && rightOperand is num) {
          return leftOperand.compareTo(rightOperand) < 0;
        }
      } else if (node.operator.type == TokenType.LT_EQ) {
        // numeric or {@code null}
        if (leftOperand is num && rightOperand is num) {
          return leftOperand.compareTo(rightOperand) <= 0;
        }
      } else if (node.operator.type == TokenType.LT_LT) {
        // integer or {@code null}
        if (leftOperand is int && rightOperand is int) {
          return leftOperand << rightOperand;
        }
      } else if (node.operator.type == TokenType.MINUS) {
        // numeric or {@code null}
        if (leftOperand is num && rightOperand is num) {
          return leftOperand - rightOperand;
        }
      } else if (node.operator.type == TokenType.PERCENT) {
        // numeric or {@code null}
        if (leftOperand is num && rightOperand is num) {
          return leftOperand.remainder(rightOperand);
        }
      } else if (node.operator.type == TokenType.PLUS) {
        // numeric or {@code null}
        if (leftOperand is num && rightOperand is num) {
          return leftOperand + rightOperand;
        }
        if (leftOperand is String && rightOperand is String) {
          return leftOperand + rightOperand;
        }
      } else if (node.operator.type == TokenType.STAR) {
        // numeric or {@code null}
        if (leftOperand is num && rightOperand is num) {
          return leftOperand * rightOperand;
        }
      } else if (node.operator.type == TokenType.SLASH) {
        // numeric or {@code null}
        if (leftOperand is num && rightOperand is num) {
          return leftOperand / rightOperand;
        }
      } else if (node.operator.type == TokenType.TILDE_SLASH) {
        // numeric or {@code null}
        if (leftOperand is num && rightOperand is num) {
          return leftOperand ~/ rightOperand;
        }
      }
      break;
    }
    // TODO(brianwilkerson): This doesn't handle numeric conversions.
    return visitExpression(node);
  }

  @override
  Object? visitDoubleLiteral(DoubleLiteral node) => node.value;

  @override
  Object? visitIntegerLiteral(IntegerLiteral node) => node.value;

  @override
  Object? visitInterpolationExpression(InterpolationExpression node) {
    var value = node.expression.accept(this);
    if (value == null || value is bool || value is String || value is num) {
      return value;
    }
    return notAConstant;
  }

  @override
  Object? visitInterpolationString(InterpolationString node) => node.value;

  @override
  Object? visitListLiteral(ListLiteral node) {
    List<Object?> list = <Object>[];
    for (CollectionElement element in node.elements) {
      if (element is Expression) {
        var value = element.accept(this);
        if (identical(value, notAConstant)) {
          return value;
        }
        list.add(value);
      } else {
        // There are a lot of constants that this class does not support, so we
        // didn't add support for the extended collection support.
        return notAConstant;
      }
    }
    return list;
  }

  @override
  Object? visitMethodInvocation(MethodInvocation node) {
    return visitNode(node);
  }

  @override
  Object? visitNode(AstNode node) => notAConstant;

  @override
  Object? visitNullLiteral(NullLiteral node) => null;

  @override
  Object? visitParenthesizedExpression(ParenthesizedExpression node) => node.expression.accept(this);

  @override
  Object? visitPrefixedIdentifier(PrefixedIdentifier node) => _getConstantValue(node, _library);

  @override
  Object? visitPrefixExpression(PrefixExpression node) {
    var operand = node.operand.accept(this);
    if (identical(operand, notAConstant)) {
      return operand;
    }
    while (true) {
      if (node.operator.type == TokenType.BANG) {
        if (identical(operand, true)) {
          return false;
        } else if (identical(operand, false)) {
          return true;
        }
      } else if (node.operator.type == TokenType.TILDE) {
        if (operand is int) {
          return ~operand;
        }
      } else if (node.operator.type == TokenType.MINUS) {
        if (operand == null) {
          return null;
        } else if (operand is num) {
          return -operand;
        }
      } else {}
      break;
    }
    return notAConstant;
  }

  // @override
  // Object? visitPropertyAccess(PropertyAccess node) => _getConstantValue(null);

  @override
  Object? visitSetOrMapLiteral(SetOrMapLiteral node) {
    // There are a lot of constants that this class does not support, so we
    // didn't add support for set literals. As a result, this assumes that we're
    // looking at a map literal until we prove otherwise.
    Map<String, Object?> map = HashMap<String, Object>();
    for (CollectionElement element in node.elements) {
      if (element is MapLiteralEntry) {
        var key = element.key.accept(this);
        var value = element.value.accept(this);
        if (key is String && !identical(value, notAConstant)) {
          map[key] = value;
        } else {
          return notAConstant;
        }
      } else {
        // There are a lot of constants that this class does not support, so
        // we didn't add support for the extended collection support.
        return notAConstant;
      }
    }
    return map;
  }

  @override
  Object? visitSimpleIdentifier(SimpleIdentifier node) => _getConstantValue(node, _library);

  @override
  Object? visitSimpleStringLiteral(SimpleStringLiteral node) => node.value;

  @override
  Object? visitStringInterpolation(StringInterpolation node) {
    StringBuffer buffer = StringBuffer();
    for (InterpolationElement element in node.elements) {
      var value = element.accept(this);
      if (identical(value, notAConstant)) {
        return value;
      }
      buffer.write(value);
    }
    return buffer.toString();
  }

  @override
  Object? visitSymbolLiteral(SymbolLiteral node) {
    StringBuffer buffer = StringBuffer();
    for (Token component in node.components) {
      if (buffer.length > 0) {
        buffer.writeCharCode(0x2E);
      }
      buffer.write(component.lexeme);
    }
    return buffer.toString();
  }

  @override
  Object? visitFieldDeclaration(FieldDeclaration node) {
    // final variable = _getFieldVariable(node.parent!, node, targetVarName);
    // final initializer = variable?.initializer;
    // if (initializer != null) {
    //   final resolved = initializer.accept(this);
    //   if (resolved != null && resolved != notAConstant) {
    //     return resolved;
    //   }
    // }
    // return notAConstant;
  }

  /// Return the constant value of the static constant represented by the given
  /// [element].
  Object? _getConstantValue(Identifier identifier, LibraryElement library) {
    if (identifier is SimpleIdentifier) {
      final (lib, node) = _resolver.astNodeFor(identifier.name, library);

      if (node is TopLevelVariableDeclaration) {
        final variable = node.variables.variables.firstWhere(
          (e) => e.name.lexeme == identifier.name,
          orElse: () => throw Exception('Identifier ${identifier.name} not found in ${lib.src.uri}'),
        );
        final initializer = variable.initializer;
        if (initializer != null) {
          final resolved = initializer.accept(this);
          if (resolved != null && resolved != notAConstant) {
            return resolved;
          }
        }
      } else if (node is FunctionDeclaration) {
        _elementResolverVisitor.visitFunctionDeclaration(node);
        final function = lib.getFunction(node.name.lexeme);
        print('Function: ${function}');
        return function?.name;
      }
    } else if (identifier is PrefixedIdentifier) {
      final targetVarName = identifier.identifier.name;
      final (lib, enclosingNode) = _resolver.astNodeFor(identifier.prefix.name, _library);
      final declaration = _lookupMemberWithName(enclosingNode, targetVarName);
      if (declaration is VariableDeclaration) {
        final initializer = declaration.initializer;
        if (initializer != null) {
          final resolved = initializer.accept(this);
          if (resolved != null && resolved != notAConstant) {
            return resolved;
          }
        }
      } else if (declaration is MethodDeclaration) {
        final tempInterfaceElm = InterfaceElementImpl(name: '_', library: lib);
        _elementResolverVisitor.visitElementScoped(tempInterfaceElm, () {
          _elementResolverVisitor.visitMethodDeclaration(declaration);
        });
        final method = tempInterfaceElm.getMethod(declaration.name.lexeme);
        print('Method: $method');
        return method?.name;
      } else if (declaration is EnumConstantDeclaration) {
        return declaration.name.lexeme;
      }
    }
    return notAConstant;
  }

  Declaration? _getFieldVariable(FieldDeclaration fieldNode, String varName) {
    final variable = fieldNode.fields.variables.firstWhere(
      (e) => e.name.lexeme == varName,
      orElse: () => throw Exception('Identifier $varName not found in ${fieldNode.fields}'),
    );
    final initializer = variable.initializer;
    if (initializer is SimpleIdentifier) {
      final fieldNode2 = _lookupMemberWithName(fieldNode.parent!, initializer.name);
      if (fieldNode2 is FieldDeclaration) {
        return _getFieldVariable(fieldNode2, varName);
      } else if (fieldNode2 != null) {
        return fieldNode2;
      }
    }
    return variable;
  }

  Declaration? _lookupMemberWithName(AstNode enclosingNode, String name) {
    final Declaration? declaration;
    if (enclosingNode is ClassDeclaration) {
      declaration = enclosingNode.members.firstWhere((e) {
        if (e is MethodDeclaration) {
          return e.name.lexeme == name;
        } else if (e is FieldDeclaration) {
          return e.fields.variables.any((e) => e.name.lexeme == name);
        }
        return false;
      }, orElse: () => throw Exception('Identifier $name not found inside ${enclosingNode.name}'));
    } else if (enclosingNode is MixinDeclaration) {
      declaration = enclosingNode.members.firstWhere((e) {
        if (e is MethodDeclaration) {
          return e.name.lexeme == name;
        } else if (e is FieldDeclaration) {
          return e.fields.variables.any((e) => e.name.lexeme == name);
        }
        return false;
      }, orElse: () => throw Exception('Identifier $name not found in ${enclosingNode.name}'));
    } else if (enclosingNode is ExtensionDeclaration) {
      declaration = enclosingNode.members.firstWhere((e) {
        if (e is MethodDeclaration) {
          return e.name.lexeme == name;
        } else if (e is FieldDeclaration) {
          return e.fields.variables.any((e) => e.name.lexeme == name);
        }
        return false;
      }, orElse: () => throw Exception('Identifier $name not found in ${enclosingNode.name}'));
    } else if (enclosingNode is EnumDeclaration) {
      declaration = enclosingNode.constants.firstWhere(
        (e) => e.name.lexeme == name,
        orElse: () => throw Exception('Identifier $name not found in ${enclosingNode.name}'),
      );
    } else {
      throw Exception('Unsupported node type: ${enclosingNode.runtimeType}');
    }
    if (declaration is FieldDeclaration) {
      return _getFieldVariable(declaration, name);
    }
    return declaration;
  }

  // final initializer = variable?.initializer;
  // if (initializer is SimpleIdentifier) {
  // return _lookupMemberField(enclosingNode, initializer.name);
  // }
  //
  // return variable;
}
