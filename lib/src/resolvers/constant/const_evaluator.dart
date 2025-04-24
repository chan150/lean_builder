import 'dart:collection';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:lean_builder/src/element/builder/element_builder.dart';
import 'package:lean_builder/src/element/builder/element_stack.dart';
import 'package:lean_builder/src/element/element.dart';
import 'package:lean_builder/src/graph/assets_graph.dart';
import 'package:lean_builder/src/graph/scan_results.dart';
import 'package:lean_builder/src/resolvers/resolver.dart';
import 'package:collection/collection.dart';
import 'package:lean_builder/src/type/type_ref.dart';

import 'constant.dart';

// some implementations of this class is borrowed from analyzer package

class ConstantEvaluator extends GeneralizingAstVisitor<Constant> with ElementStack<Constant> {
  final Resolver _resolver;

  final ElementBuilder _elementResolverVisitor;

  LibraryElement get _library => currentLibrary();

  ConstantEvaluator(this._resolver, LibraryElement library, this._elementResolverVisitor) {
    pushElement(library);
  }

  Constant? evaluate(AstNode node) {
    final key = _resolver.evaluatedConstantsCache.keyFor(_library.src.id, '${node.hashCode}');
    if (_resolver.evaluatedConstantsCache.contains(key)) {
      return _resolver.evaluatedConstantsCache[key];
    }
    final constant = node.accept(this);
    if (constant != null && !identical(constant, Constant.invalid)) {
      _resolver.evaluatedConstantsCache.cacheKey(key, constant);
    }
    return constant;
  }

  @override
  Constant? visitConstructorDeclaration(ConstructorDeclaration node) {
    // redirect constant evaluation to the redirected constructor
    final redirectConstructor = node.redirectedConstructor;
    if (redirectConstructor != null) {
      final redType = redirectConstructor.type;
      final identifierRef = _resolver.resolveIdentifier(_library, [
        if (redType.importPrefix != null) redType.importPrefix!.name.lexeme,
        redType.name2.lexeme,
      ]);
      final (redirectLib, redirectConstroctor, _) = _resolver.astNodeFor(identifierRef, _library);
      if (redirectConstroctor is! ConstructorDeclaration) {
        throw Exception('Expected ConstructorDeclaration, but got ${redirectConstroctor.runtimeType}');
      }
      return visitElementScoped(redirectLib, () {
        return evaluate(redirectConstroctor);
      });
    }

    final interfaceDec = node.parent as NamedCompilationUnitMember;
    assert(interfaceDec is ClassDeclaration || interfaceDec is EnumDeclaration);
    ConstObjectImpl? superConstObj;
    final initializers = node.initializers;
    if (interfaceDec is ClassDeclaration) {
      final superClass = interfaceDec.extendsClause?.superclass;
      if (superClass != null) {
        final superConstInvocations = initializers.whereType<SuperConstructorInvocation>();
        final superConstName = superConstInvocations.firstOrNull?.constructorName?.name;
        final (superLib, superNode as ClassDeclaration, loc) = _resolver.astNodeFor(
          IdentifierRef.fromType(superClass),
          _library,
        );
        visitElementScoped(superLib, () {
          final constructors = superNode.members.whereType<ConstructorDeclaration>();
          final superConstructor = constructors.where((c) => c.name?.lexeme == superConstName).single;
          superConstObj = evaluate(superConstructor) as ConstObjectImpl?;
        });
      }
    }

    final fields = interfaceDec.childEntities.whereType<FieldDeclaration>();
    final params = node.parameters.parameters;
    final values = <String, Constant?>{};
    final positionalNames = <int, String>{};

    for (final initializer in initializers) {
      if (initializer is ConstructorFieldInitializer) {
        values[initializer.fieldName.name] = initializer.expression.accept(this);
      } else if (initializer is SuperConstructorInvocation) {
        superConstObj = superConstObj?.mergeArgs(initializer.argumentList, this);
      }
    }
    if (superConstObj != null) {
      values.addAll(superConstObj!.props);
    }
    for (final field in fields.where((f) => !f.isStatic)) {
      for (final variable in field.fields.variables) {
        if (variable.initializer != null) {
          values[variable.name.lexeme] = variable.initializer!.accept(this);
        }
      }
    }

    for (var i = 0; i < params.length; i++) {
      final param = params[i];
      if (param.isPositional) {
        positionalNames[i] = param.name!.lexeme;
      }
      if (param is DefaultFormalParameter && param.defaultValue != null) {
        values[param.name!.lexeme] = param.defaultValue?.accept(this);
      }
    }

    final interfaceName = interfaceDec.name.lexeme;
    final type = NamedTypeRefImpl(
      interfaceName,
      _library.buildDeclarationRef(interfaceName, TopLevelIdentifierType.$class),
    );
    return ConstObjectImpl(values, type, positionalNames: positionalNames);
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

  dynamic _valueOf(Constant? constant) {
    if (constant is ConstValue) {
      return constant.value;
    }
    return null;
  }

  @override
  Constant? visitBinaryExpression(BinaryExpression node) {
    var leftOperand = _valueOf(node.leftOperand.accept(this));
    if (identical(leftOperand, Constant.invalid)) {
      return leftOperand;
    }
    var rightOperand = _valueOf(node.rightOperand.accept(this));
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
    final target = node.target;
    final parts = [
      if (target is SimpleIdentifier) target.name,
      if (target is PrefixedIdentifier) ...[target.prefix.name, target.identifier.name],
      node.methodName.name,
    ];
    if (parts.length < 3) {
      parts.add('');
    }
    final identifierRef = _resolver.resolveIdentifier(_library, parts);
    final (lib, constructorNode, loc) = _resolver.astNodeFor(identifierRef, _library);

    if (constructorNode is! ConstructorDeclaration) {
      throw Exception('Expected ConstructorDeclaration, but got ${constructorNode.runtimeType}');
    }
    final constant = visitElementScoped(lib, () {
      return evaluate(constructorNode);
    });

    if (constant is ConstObjectImpl) {
      return constant.mergeArgs(node.argumentList, this);
    }
    return Constant.invalid;
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
    var operand = _valueOf(node.operand.accept(this));
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
        var key = _valueOf(element.key.accept(this));
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
    final namedUnit = node.thisOrAncestorOfType<NamedCompilationUnitMember>();
    String? prefix;
    if (namedUnit != null) {
      bool isMember = namedUnit.childEntities.whereType<ClassMember>().any((m) {
        if (m is MethodDeclaration) {
          return m.name.lexeme == node.name;
        } else if (m is FieldDeclaration) {
          return m.fields.variables.any((v) => v.name.lexeme == node.name);
        }
        return false;
      });
      if (isMember) {
        prefix = namedUnit.name.lexeme;
      }
    }
    return _getConstantValue(IdentifierRef(node.name, prefix: prefix), _library);
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
  /// [objectArg].
  Constant _getConstantValue(IdentifierRef ref, LibraryElement library) {
    final (lib, node, loc) = _resolver.astNodeFor(ref, library);

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
      final function = lib.getElement(node.name.lexeme);
      if (function is FunctionElement) {
        return ConstFunctionReferenceImpl(node.name.lexeme, function.type, loc);
      } else {
        throw Exception('Function ${node.name.lexeme} not found in ${lib.src.uri}');
      }
    } else if (node is NamedCompilationUnitMember) {
      final type = NamedTypeRefImpl(node.name.lexeme, loc);
      return ConstTypeRef(type);
    } else if (node is MethodDeclaration) {
      assert(node.isStatic, 'Methods reference in constant context should be static');
      final tempInterfaceElm = InterfaceElementImpl(name: '_', library: lib);
      _elementResolverVisitor.visitElementScoped(tempInterfaceElm, () {
        _elementResolverVisitor.visitMethodDeclaration(node);
      });
      final method = tempInterfaceElm.getMethod(node.name.lexeme);
      if (method == null) {
        throw Exception('Method ${node.name.lexeme} not found in ${lib.src.uri}');
      }
      return ConstFunctionReferenceImpl(node.name.lexeme, method.type, loc);
    } else if (node is EnumConstantDeclaration) {
      final enumDeclaration = node.thisOrAncestorOfType<EnumDeclaration>();
      return ConstEnumValue(enumDeclaration?.name.lexeme ?? '', node.name.lexeme);
    } else if (node is FieldDeclaration) {
      assert(node.isStatic, 'Fields reference in constant context should be static');
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
