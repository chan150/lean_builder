// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:code_genie/src/resolvers/element/element.dart';
import 'package:code_genie/src/resolvers/element_resolver.dart';
import 'package:code_genie/src/resolvers/type/type_ref.dart';
import 'package:code_genie/src/resolvers/visitor/element_resolver_visitor.dart';

import 'constant.dart';

class ConstantEvaluator extends GeneralizingAstVisitor<Constant> {
  final ElementResolver _resolver;

  final ElementResolverVisitor _elementResolverVisitor;

  final LibraryElement _library;

  ConstantEvaluator(this._resolver, this._library, this._elementResolverVisitor);

  Constant evaluate(AstNode node) {
    return node.accept(this) ?? Constant.invalid;
  }

  @override
  Constant? visitAdjacentStrings(AdjacentStrings node) {
    StringBuffer buffer = StringBuffer();
    for (StringLiteral string in node.strings) {
      var value = string.accept(this);
      if (identical(value, Constant.invalid)) {
        return value;
      }
      buffer.write(value);
    }
    return ConstString(buffer.toString());
  }

  @override
  Constant? visitBinaryExpression(BinaryExpression node) {
    var leftOperand = node.leftOperand.accept(this)?.value;
    if (identical(leftOperand, Constant.invalid)) {
      return leftOperand;
    }
    var rightOperand = node.rightOperand.accept(this)?.value;
    if (identical(rightOperand, Constant.invalid)) {
      return rightOperand;
    }
    while (true) {
      if (node.operator.type == TokenType.AMPERSAND) {
        // integer or {@code null}
        if (leftOperand is int && rightOperand is int) {
          return ConstInt(leftOperand & rightOperand);
        }
      } else if (node.operator.type == TokenType.AMPERSAND_AMPERSAND) {
        // boolean or {@code null}
        if (leftOperand is bool && rightOperand is bool) {
          return ConstBool(leftOperand && rightOperand);
        }
      } else if (node.operator.type == TokenType.BANG_EQ) {
        // numeric, string, boolean, or {@code null}
        if (leftOperand is bool && rightOperand is bool) {
          return ConstBool(leftOperand != rightOperand);
        } else if (leftOperand is num && rightOperand is num) {
          return ConstBool(leftOperand != rightOperand);
        } else if (leftOperand is String && rightOperand is String) {
          return ConstBool(leftOperand != rightOperand);
        }
      } else if (node.operator.type == TokenType.BAR) {
        // integer or {@code null}
        if (leftOperand is int && rightOperand is int) {
          return ConstInt(leftOperand | rightOperand);
        }
      } else if (node.operator.type == TokenType.BAR_BAR) {
        // boolean or {@code null}
        if (leftOperand is bool && rightOperand is bool) {
          return ConstBool(leftOperand || rightOperand);
        }
      } else if (node.operator.type == TokenType.CARET) {
        // integer or {@code null}
        if (leftOperand is int && rightOperand is int) {
          return ConstInt(leftOperand ^ rightOperand);
        }
      } else if (node.operator.type == TokenType.EQ_EQ) {
        // numeric, string, boolean, or {@code null}
        if (leftOperand is bool && rightOperand is bool) {
          return ConstBool(leftOperand == rightOperand);
        } else if (leftOperand is num && rightOperand is num) {
          return ConstBool(leftOperand == rightOperand);
        } else if (leftOperand is String && rightOperand is String) {
          return ConstBool(leftOperand == rightOperand);
        }
      } else if (node.operator.type == TokenType.GT) {
        // numeric or {@code null}
        if (leftOperand is num && rightOperand is num) {
          return ConstBool(leftOperand.compareTo(rightOperand) > 0);
        }
      } else if (node.operator.type == TokenType.GT_EQ) {
        // numeric or {@code null}
        if (leftOperand is num && rightOperand is num) {
          return ConstBool(leftOperand.compareTo(rightOperand) >= 0);
        }
      } else if (node.operator.type == TokenType.GT_GT) {
        // integer or {@code null}
        if (leftOperand is int && rightOperand is int) {
          return ConstInt(leftOperand >> rightOperand);
        }
      } else if (node.operator.type == TokenType.GT_GT_GT) {
        if (leftOperand is int && rightOperand is int) {
          return ConstInt(rightOperand >= 64 ? 0 : (leftOperand >> rightOperand) & ((1 << (64 - rightOperand)) - 1));
        }
      } else if (node.operator.type == TokenType.LT) {
        // numeric or {@code null}
        if (leftOperand is num && rightOperand is num) {
          return ConstBool(leftOperand.compareTo(rightOperand) < 0);
        }
      } else if (node.operator.type == TokenType.LT_EQ) {
        // numeric or {@code null}
        if (leftOperand is num && rightOperand is num) {
          return ConstBool(leftOperand.compareTo(rightOperand) <= 0);
        }
      } else if (node.operator.type == TokenType.LT_LT) {
        // integer or {@code null}
        if (leftOperand is int && rightOperand is int) {
          return ConstInt(leftOperand << rightOperand);
        }
      } else if (node.operator.type == TokenType.MINUS) {
        // numeric or {@code null}
        if (leftOperand is num && rightOperand is num) {
          return ConstNum(leftOperand - rightOperand);
        }
      } else if (node.operator.type == TokenType.PERCENT) {
        // numeric or {@code null}
        if (leftOperand is num && rightOperand is num) {
          return ConstNum(leftOperand.remainder(rightOperand));
        }
      } else if (node.operator.type == TokenType.PLUS) {
        // numeric or {@code null}
        if (leftOperand is num && rightOperand is num) {
          return ConstNum(leftOperand + rightOperand);
        }
        if (leftOperand is String && rightOperand is String) {
          return ConstString(leftOperand + rightOperand);
        }
      } else if (node.operator.type == TokenType.STAR) {
        // numeric or {@code null}
        if (leftOperand is num && rightOperand is num) {
          return ConstNum(leftOperand * rightOperand);
        }
      } else if (node.operator.type == TokenType.SLASH) {
        // numeric or {@code null}
        if (leftOperand is num && rightOperand is num) {
          return ConstNum(leftOperand / rightOperand);
        }
      } else if (node.operator.type == TokenType.TILDE_SLASH) {
        // numeric or {@code null}
        if (leftOperand is num && rightOperand is num) {
          return ConstNum(leftOperand ~/ rightOperand);
        }
      }
      break;
    }
    // TODO This doesn't handle numeric conversions.
    return visitExpression(node);
  }

  @override
  Constant? visitInstanceCreationExpression(InstanceCreationExpression node) {
    print('InstanceCreationExpression: ${node.constructorName}');
    return Constant.invalid;
  }

  @override
  Constant? visitAnnotation(Annotation node) {
    var value = node.arguments?.accept(this);
    if (value == null || value is ConstBool || value is ConstString || value is ConstNum) {
      return value;
    }
    return Constant.invalid;
  }

  @override
  Constant? visitDoubleLiteral(DoubleLiteral node) => ConstDouble(node.value);

  @override
  Constant? visitIntegerLiteral(IntegerLiteral node) => node.value == null ? null : ConstInt(node.value!);

  @override
  Constant? visitInterpolationExpression(InterpolationExpression node) {
    var value = node.expression.accept(this);
    if (value == null || value is ConstBool || value is ConstString || value is ConstNum) {
      return value;
    }
    return Constant.invalid;
  }

  @override
  Constant? visitBooleanLiteral(BooleanLiteral node) => ConstBool(node.value);

  @override
  Constant? visitInterpolationString(InterpolationString node) => ConstString(node.value);

  @override
  Constant? visitListLiteral(ListLiteral node) {
    List<Constant> list = <Constant>[];
    for (CollectionElement element in node.elements) {
      if (element is Expression) {
        var value = element.accept(this);
        if (value == null || identical(value, Constant.invalid)) {
          return value;
        }
        list.add(value);
      } else {
        // There are a lot of constants that this class does not support, so we
        // didn't add support for the extended collection support.
        return Constant.invalid;
      }
    }
    return ConstList(list);
  }

  @override
  Constant? visitMethodInvocation(MethodInvocation node) {
    print('MethodInvocation: ${node.methodName}');
    return Constant.invalid;
    final element = _elementResolverVisitor.resolveTopLevelElement(IdentifierRef.from(node.methodName), _library);

    if (element is! InterfaceElement) return Constant.invalid;
    for (final field in element.fields) {
      print('${field.name} ${field.constantValue}');
    }

    Map<String, Constant> argumentValues = {};
    final argumentList = node.argumentList.arguments;
    if (argumentList.isNotEmpty) {
      for (var i = 0; i < argumentList.length; i++) {
        final arg = argumentList[i];
        if (arg is NamedExpression) {
          final name = arg.name.label.name;
          final value = arg.expression.accept(this);
          if (value != null) {
            argumentValues[name] = value;
          }
        } else {
          final value = arg.accept(this);
          if (value != null) {
            argumentValues['$i'] = value;
          }
        }
      }
    }
    print(argumentValues);
  }

  @override
  Constant? visitNode(AstNode node) => Constant.invalid;

  @override
  Constant? visitNullLiteral(NullLiteral node) => null;

  @override
  Constant? visitParenthesizedExpression(ParenthesizedExpression node) => node.expression.accept(this);

  @override
  Constant? visitPropertyAccess(PropertyAccess node) {
    final target = node.realTarget;
    if (target is PrefixedIdentifier) {
      return _getConstantValue(
        IdentifierRef(node.propertyName.name, prefix: target.identifier.name, importPrefix: target.prefix.name),
        _library,
      );
    }
    return Constant.invalid;
  }

  @override
  Constant? visitPrefixedIdentifier(PrefixedIdentifier node) {
    return _getConstantValue(IdentifierRef.from(node), _library);
  }

  @override
  Constant? visitPrefixExpression(PrefixExpression node) {
    var operand = node.operand.accept(this)?.value;
    if (identical(operand, Constant.invalid)) {
      return operand;
    }
    while (true) {
      if (node.operator.type == TokenType.BANG) {
        if (identical(operand, true)) {
          return ConstBool(false);
        } else if (identical(operand, false)) {
          return ConstBool(true);
        }
      } else if (node.operator.type == TokenType.TILDE) {
        if (operand is int) {
          return ConstInt(~operand);
        }
      } else if (node.operator.type == TokenType.MINUS) {
        if (operand == null) {
          return null;
        } else if (operand is num) {
          return ConstNum(-operand);
        }
      } else {}
      break;
    }
    return Constant.invalid;
  }

  // @override
  // Object? visitPropertyAccess(PropertyAccess node) => _getConstantValue(null);

  @override
  Constant? visitSetOrMapLiteral(SetOrMapLiteral node) {
    // There are a lot of constants that this class does not support, so we
    // didn't add support for set literals. As a result, this assumes that we're
    // looking at a map literal until we prove otherwise.
    Map<String, Constant> map = HashMap<String, Constant>();
    for (CollectionElement element in node.elements) {
      if (element is MapLiteralEntry) {
        var key = element.key.accept(this)?.value;
        var value = element.value.accept(this);
        if (key is String && value != null && !identical(value, Constant.invalid)) {
          map[key] = value;
        } else {
          return Constant.invalid;
        }
      } else {
        // There are a lot of constants that this class does not support, so
        // we didn't add support for the extended collection support.
        return Constant.invalid;
      }
    }
    return ConstMap(map);
  }

  @override
  Constant? visitSimpleIdentifier(SimpleIdentifier node) {
    if (node.parent is VariableDeclaration) {
      // this coming from initializer of a variable
      return _getConstantValue(IdentifierRef(node.name), _library);
    }
    final enclosingNode = node.thisOrAncestorOfType<NamedCompilationUnitMember>();
    return _getConstantValue(IdentifierRef(node.name, prefix: enclosingNode?.name.lexeme), _library);
  }

  @override
  Constant? visitFunctionReference(FunctionReference node) {
    final value = node.function.accept(this);
    if (value is ConstFunctionReferenceImpl) {
      for (final typeArg in [...?node.typeArguments?.arguments]) {
        final type = _elementResolverVisitor.resolveTypeRef((typeArg), _library);
        value.addTypeArgument(type);
      }
    }
    return value;
  }

  @override
  Constant? visitSimpleStringLiteral(SimpleStringLiteral node) => ConstString(node.value);

  @override
  Constant? visitStringInterpolation(StringInterpolation node) {
    StringBuffer buffer = StringBuffer();
    for (InterpolationElement element in node.elements) {
      var value = element.accept(this);
      if (identical(value, Constant.invalid)) {
        return value;
      }
      buffer.write(value);
    }
    return ConstString(buffer.toString());
  }

  @override
  Constant? visitSymbolLiteral(SymbolLiteral node) {
    StringBuffer buffer = StringBuffer();
    for (Token component in node.components) {
      if (buffer.length > 0) {
        buffer.writeCharCode(0x2E);
      }
      buffer.write(component.lexeme);
    }
    return ConstSymbol(buffer.toString());
  }

  /// Return the constant value of the static constant represented by the given
  /// [type].
  Constant _getConstantValue(IdentifierRef ref, LibraryElement library) {
    final (lib, node) = _resolver.astNodeFor(ref, library);

    if (node is TopLevelVariableDeclaration) {
      final variable = node.variables.variables.firstWhere(
        (e) => e.name.lexeme == ref.topLevelTarget,
        orElse: () => throw Exception('Identifier ${ref.topLevelTarget} not found in ${lib.src.uri}'),
      );
      final initializer = variable.initializer;
      if (initializer != null) {
        final resolved = initializer.accept(this);
        if (resolved != null && !identical(resolved, Constant.invalid)) {
          return resolved;
        }
      }
    } else if (node is FunctionDeclaration) {
      _elementResolverVisitor.visitFunctionDeclaration(node);
      final function = lib.getFunction(node.name.lexeme);
      return ConstFunctionReferenceImpl(node.name.lexeme, function?.type);
    } else if (node is MethodDeclaration) {
      assert(node.isStatic, 'Methods reference in const context should be static');
      final tempInterfaceElm = InterfaceElementImpl(name: '_', library: lib);
      _elementResolverVisitor.visitElementScoped(tempInterfaceElm, () {
        _elementResolverVisitor.visitMethodDeclaration(node);
      });
      final method = tempInterfaceElm.getMethod(node.name.lexeme);
      return ConstFunctionReferenceImpl(node.name.lexeme, method?.type);
    } else if (node is EnumConstantDeclaration) {
      final enumDeclaration = node.thisOrAncestorOfType<EnumDeclaration>();
      return ConstEnumValue(enumDeclaration?.name.lexeme ?? '', node.name.lexeme);
    } else if (node is FieldDeclaration) {
      assert(node.isStatic, 'Fields reference in const context should be static');
      final variable = node.fields.variables.firstWhere(
        (e) => e.name.lexeme == ref.name,
        orElse: () => throw Exception('Identifier ${ref.name} not found in ${lib.src.uri}'),
      );
      final initializer = variable.initializer;
      if (initializer != null) {
        final resolved = initializer.accept(this);
        if (resolved != null && !identical(resolved, Constant.invalid)) {
          return resolved;
        }
      }
    }
    return Constant.invalid;
  }
}
