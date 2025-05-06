import 'dart:math';

// ignore: implementation_imports
import 'package:_fe_analyzer_shared/src/scanner/scanner.dart' as fasta;
import 'package:analyzer/dart/ast/token.dart' show TokenType, Keyword, Token;
import 'package:lean_builder/src/asset/asset.dart';
import 'package:lean_builder/src/asset/package_file_resolver.dart';
import 'package:lean_builder/src/build_script/annotations.dart';
import 'package:lean_builder/src/graph/scan_results.dart';
import 'package:lean_builder/src/logger.dart';

import 'directive_statement.dart';

class AssetsScanner {
  final ScanResults results;
  final PackageFileResolver fileResolver;

  AssetsScanner(this.results, this.fileResolver);

  void scan(Asset asset, {bool forceOverride = false}) {
    try {
      if (results.isVisited(asset.id) && !forceOverride) return;

      final bytes = asset.readAsBytesSync();

      results.addAsset(asset);

      Token? token = fasta.scan(bytes).tokens;
      String? libraryName;
      int annotationFlag = 0;

      while (token != null && !token.isEof && token.next != null) {
        token = _skipCurlyBrackets(token);
        if (token.isEof) break;
        Token nextToken = token.next!;
        if (token.type == TokenType.AT) {
          if (kBuilderAnnotationNames.contains(nextToken.lexeme)) {
            annotationFlag |= 2;
          } else {
            annotationFlag |= 1;
          }
          token = nextToken;
          // could be import-prefixed or has a named constructor
          while (token?.next?.type == TokenType.PERIOD) {
            token = token?.next?.next;
          }
          token = _skipParenthesis(token?.next);
          continue;
        } else if (token.isTopLevelKeyword) {
          if (nextToken.isTopLevelKeyword) {
            token = nextToken;
            continue;
          }
          final type = token.type;
          final nextLexeme = nextToken.lexeme;
          switch (type) {
            case Keyword.LIBRARY:
              final (nextT, name) = _tryParseLibraryDirective(nextToken);
              libraryName = name;
              nextToken = nextT ?? nextToken;
              break;
            case Keyword.IMPORT:
            case Keyword.EXPORT:
            case Keyword.PART:
              final (nextT, direcitve) = _tryParseDirective(type, nextToken, asset);
              nextToken = nextT ?? nextToken;
              if (direcitve != null) {
                results.addDirective(asset, direcitve);
              }
              break;
            case Keyword.TYPEDEF:
              nextToken = parseTypeDef(nextToken, asset) ?? nextToken;
              break;
            case Keyword.CLASS:
              results.addDeclaration(nextLexeme, asset, SymbolType.$class);
              nextToken = _skipUntilAny(token, {TokenType.OPEN_CURLY_BRACKET, TokenType.SEMICOLON});
              break;
            case Keyword.MIXIN:
              if (nextToken.type == Keyword.CLASS) {
                break;
              }
              results.addDeclaration(nextLexeme, asset, SymbolType.$mixin);
              nextToken = _skipUntil(token, TokenType.OPEN_CURLY_BRACKET);
              break;
            case Keyword.ENUM:
              results.addDeclaration(nextLexeme, asset, SymbolType.$enum);
              nextToken = _skipUntil(token, TokenType.OPEN_CURLY_BRACKET);
              break;
            case Keyword.EXTENSION:
              String extName = nextLexeme;
              if (nextLexeme == 'type') {
                Token? current = nextToken.next;
                if (current != null && current.isKeyword) {
                  current = current.next;
                }
                if (current != null && current.isIdentifier) {
                  extName = current.lexeme;
                }
              }
              results.addDeclaration(extName, asset, SymbolType.$extension);

              nextToken = _skipUntil(nextToken, TokenType.OPEN_CURLY_BRACKET);
              break;
          }
        } else if ({Keyword.CONST, Keyword.FINAL, Keyword.VAR, Keyword.LATE}.contains(token.type) &&
            nextToken.isIdentifier) {
          if (token.type == Keyword.CONST) {
            _tryParseConstVar(nextToken, asset);
          }
          nextToken = _skipUntil(nextToken, TokenType.SEMICOLON);
        } else if (token.isIdentifier) {
          nextToken = _tryParseFunction(token, asset) ?? nextToken;
        }

        token = nextToken;
      }

      results.updateAssetInfo(asset, content: bytes, annotationFlag: annotationFlag, libraryName: libraryName);
    } catch (e, stack) {
      Logger.error('Error scanning asset ${asset.uri} ${e.toString()}', stackTrace: stack);
    }
  }

  (Token?, String?) _tryParseLibraryDirective(fasta.Token nextToken) {
    if (nextToken.type == TokenType.SEMICOLON) {
      nextToken = nextToken.next!;
      return (nextToken, null);
    }
    String name = '';
    Token? nameToken = nextToken;
    while (nameToken != null && nameToken.type != TokenType.SEMICOLON && !nameToken.isEof) {
      name += nameToken.lexeme;
      nameToken = nameToken.next;
    }
    return (nameToken?.next, name);
  }

  Token? _tryParseFunction(Token token, Asset asset) {
    Token? current = _skipLTGT(token);
    current = _skipParenthesis(current);

    bool funcFound = false;
    Token? next = current?.next;
    if (current?.type == Keyword.FUNCTION) {
      current = current?.next;
    } else if (next != null && _skipLTGT(next).type == TokenType.OPEN_PAREN) {
      funcFound = true;
      if (_isValidName(current?.lexeme)) {
        results.addDeclaration(current!.lexeme, asset, SymbolType.$function);
      }
    } else if (next != null && next.type == TokenType.LT) {
      return _skipLTGT(next);
    }

    if (!funcFound) {
      return current?.next;
    }

    while (current != null &&
        !current.isEof &&
        current.type != TokenType.OPEN_CURLY_BRACKET &&
        current.type != TokenType.FUNCTION &&
        current.type != TokenType.SEMICOLON) {
      current = current.next;
    }
    if (current?.type == TokenType.OPEN_CURLY_BRACKET) {
      return current;
    } else if (current != null && current.type == TokenType.FUNCTION) {
      current = _skipUntil(current, TokenType.SEMICOLON).next;
    } else if (current != null && current.type == TokenType.SEMICOLON) {
      current = current.next;
    }
    return current;
  }

  void _tryParseConstVar(Token nextToken, Asset asset) {
    Token? currentToken = nextToken;
    // Skip type information to get to the variable name
    while (currentToken != null && currentToken.type != TokenType.SEMICOLON) {
      if (currentToken.isIdentifier) {
        var afterIdentifier = currentToken.next;
        if (afterIdentifier != null && (afterIdentifier.type == TokenType.EQ)) {
          results.addDeclaration(currentToken.lexeme, asset, SymbolType.$variable);
          break;
        }
      }
      currentToken = currentToken.next;
    }
  }

  (Token?, DirectiveStatement?) _tryParseDirective(TokenType keyword, Token next, Asset enclosingAsset) {
    bool isPartOf = keyword == Keyword.PART && next.type == Keyword.OF;
    String stringUri = '';

    Token? current = next.next;

    if (isPartOf) {
      // could be pointing to a library directive which can have chained String Tokens
      if (current?.type == TokenType.STRING) {
        stringUri = current!.lexeme;
      } else {
        while (current != null && !current.isEof && current.type != TokenType.SEMICOLON) {
          stringUri += current.lexeme;
          current = current.next;
        }
        if (stringUri.isNotEmpty) {
          results.addLibraryPartOf(stringUri, enclosingAsset);
        }
        return (current, null);
      }
    } else {
      stringUri = next.lexeme;
    }

    if (stringUri.length < 3) {
      return (_skipUntil(next, TokenType.SEMICOLON), null);
    }

    // remove quotes
    stringUri = stringUri.substring(1, stringUri.length - 1);
    final uri = Uri.parse(stringUri);

    // skip private package imports
    if (uri.scheme == 'package' && uri.path.isNotEmpty && uri.path[0] == '_') {
      return (_skipUntil(next, TokenType.SEMICOLON), null);
    }

    final asset = fileResolver.assetForUri(uri, relativeTo: enclosingAsset);

    final show = <String>[];
    final hide = <String>[];
    String? prefix;
    var deferred = false;
    var showMode = true;
    for (current; current != null && !current.isEof; current = current.next) {
      if (current.type == TokenType.AS) {
        if (current.previous?.type == Keyword.DEFERRED) {
          deferred = true;
        }
        current = current.next;
        prefix = current?.lexeme;
        if (current?.next == null) break;
        current = current!.next!;
      } else if (current.type == Keyword.SHOW) {
        showMode = true;
      } else if (current.type == Keyword.HIDE) {
        showMode = false;
      } else if (current.type == TokenType.IDENTIFIER) {
        if (showMode) {
          show.add(current.lexeme);
        } else {
          hide.add(current.lexeme);
        }
      }
      if (current.type == TokenType.SEMICOLON) break;
    }

    final type = switch (keyword) {
      Keyword.IMPORT => DirectiveStatement.import,
      Keyword.EXPORT => DirectiveStatement.export,
      Keyword.PART => isPartOf ? DirectiveStatement.partOf : DirectiveStatement.part,
      _ => throw UnimplementedError('Unknown directive type: $keyword'),
    };

    final directive = DirectiveStatement(
      type: type,
      stringUri: stringUri,
      asset: asset,
      show: show,
      hide: hide,
      prefix: prefix,
      deferred: deferred,
    );
    return (current, directive);
  }

  Token? parseTypeDef(Token? token, Asset asset) {
    final identifiers = <Token>[];
    int scopeTracker = 0;
    while (token != null && token.type != TokenType.EOF) {
      token = _skipLTGT(token);
      token = _skipParenthesis(token);
      if (scopeTracker == 0 && (token != null && token.isIdentifier || token?.type == TokenType.EQ)) {
        identifiers.add(token!);
      }
      if (token?.type == TokenType.SEMICOLON) {
        token = token?.next;
        break;
      }
      token = token?.next;
    }

    final eqIndex = identifiers.indexWhere((e) => e.type == TokenType.EQ);
    final nameLexeme = eqIndex > 0 ? identifiers[eqIndex - 1].lexeme : identifiers.lastOrNull?.lexeme;
    if (_isValidName(nameLexeme)) {
      results.addDeclaration(nameLexeme!, asset, SymbolType.$typeAlias);
    }

    return token;
  }

  bool _isValidName(String? identifier) {
    return identifier != null && identifier.isNotEmpty;
  }

  Token _skipUntil(Token current, TokenType until) {
    while (current.type != until && !current.isEof) {
      current = current.next!;
    }
    return current;
  }

  Token _skipUntilAny(Token current, Set<TokenType> until) {
    while (!current.isEof && !until.contains(current.type)) {
      current = current.next!;
    }
    return current;
  }

  Token _skipCurlyBrackets(Token token) {
    if (token.type != TokenType.OPEN_CURLY_BRACKET) {
      return token;
    }
    int scopeTracker = 1;
    Token? current = token.next;
    while (current != null && !current.isEof && scopeTracker != 0) {
      switch (current.type) {
        case TokenType.OPEN_CURLY_BRACKET:
        case TokenType.STRING_INTERPOLATION_EXPRESSION:
          scopeTracker += 1;
          break;
        case TokenType.CLOSE_CURLY_BRACKET:
          scopeTracker = max(0, scopeTracker - 1);
      }
      current = current.next;
    }
    return current ?? token;
  }

  Token _skipLTGT(Token token) {
    if (token.type != TokenType.LT) {
      return token;
    }
    int scopeTracker = 1;
    Token? current = token.next;
    while (current != null && !current.isEof && scopeTracker != 0) {
      switch (current.type) {
        case TokenType.LT:
          scopeTracker += 1;
          break;
        case TokenType.LT_LT:
          scopeTracker += 2;
          break;
        case TokenType.GT:
          scopeTracker = max(0, scopeTracker - 1);
          break;
        case TokenType.GT_GT:
          scopeTracker = max(0, scopeTracker - 2);
          break;
        case TokenType.GT_GT_GT:
          scopeTracker = max(0, scopeTracker - 3);
          break;
      }
      current = current.next;
    }
    return current ?? token;
  }

  Token? _skipParenthesis(Token? token) {
    if (token == null) {
      return null;
    }
    if (token.type != TokenType.OPEN_PAREN) {
      return token;
    }
    int scopeTracker = 1;
    Token? current = token.next;
    while (current != null && !current.isEof && scopeTracker != 0) {
      switch (current.type) {
        case TokenType.OPEN_PAREN:
          scopeTracker += 1;
          break;
        case TokenType.CLOSE_PAREN:
          scopeTracker = max(0, scopeTracker - 1);
      }
      current = current.next;
    }
    return current ?? token;
  }
}
