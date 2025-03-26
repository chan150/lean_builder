import 'dart:math';

// ignore: implementation_imports
import 'package:_fe_analyzer_shared/src/scanner/scanner.dart' as fasta;
import 'package:analyzer/dart/ast/token.dart';
import 'package:code_genie/src/resolvers/package_file_resolver.dart';
import 'package:code_genie/src/scanner/scan_results.dart';

import '../resolvers/file_asset.dart';
import 'directive_statement.dart';

class TopLevelScanner {
  final ScanResults results;
  final PackageFileResolver fileResolver;

  TopLevelScanner(this.results, this.fileResolver);

  void scanFile(AssetFile asset) {
    try {
      if (results.isVisited(asset.id)) return;
      final bytes = asset.readAsBytesSync();
      results.addAsset(asset);
      var token = fasta.scan(bytes).tokens;
      final directives = <DirectiveStatement>{};
      bool hasTopLevelAnnotation = false;

      while (!token.isEof && token.next != null) {
        token = _skipCurlyBrackets(token);
        if (token.isEof) break;
        Token nextToken = token.next!;
        if (token.type == TokenType.AT) {
          hasTopLevelAnnotation = true;
          if (nextToken.next != null) {
            token = _skipParenthesis(nextToken.next!);
          }
          continue;
        } else if (token.isTopLevelKeyword) {
          final type = token.type;
          final nextLexeme = nextToken.lexeme;
          switch (type) {
            case Keyword.IMPORT:
            case Keyword.EXPORT:
            case Keyword.PART:
              if (type != Keyword.PART || nextToken.type != Keyword.OF) {
                final (directive, nextT) = _tryParseDirective(type, nextToken, asset);
                if (directive != null) {
                  directives.add(directive);
                }
                nextToken = nextT ?? nextToken;
              }
              break;
            case Keyword.TYPEDEF:
              nextToken = parseTypeDef(nextToken, asset) ?? nextToken;
              break;
            case Keyword.CLASS:
            case Keyword.MIXIN:
            case Keyword.ENUM:
            case Keyword.EXTENSION:
              if (_isValidName(nextLexeme)) {
                results.addDeclaration(nextLexeme, asset, IdentifierType.fromKeyword(type));
              }
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
      results.updateFileInfo(asset, content: bytes, hasAnnotation: hasTopLevelAnnotation);

      for (final directive in directives) {
        if (directive.type == Keyword.EXPORT) {
          results.addExport(asset, directive);
        } else if (directive.type == Keyword.PART) {
          results.addExport(asset, directive);
          results.addImport(asset, directive);
        } else {
          results.addImport(asset, directive);
        }
      }
    } catch (e) {
      print('Error scanning file: ${asset.path}');
      // if (e is Error) {
      //   print(e.stackTrace);
      // } else {
      //   print(StackTrace.current);
      // }
      // Silent error handling
    }
  }

  Token? _tryParseFunction(Token token, AssetFile asset) {
    Token? current = _skipLTGT(token);
    current = _skipParenthesis(current);

    bool funcFound = false;
    final next = current.next;
    if (current.type == Keyword.FUNCTION) {
      current = current.next!;
    } else if (next != null && _skipLTGT(next).type == TokenType.OPEN_PAREN) {
      funcFound = true;
      if (_isValidName(current.lexeme)) {
        results.addDeclaration(current.lexeme, asset, IdentifierType.$function);
      }
    } else if (next != null && next.type == TokenType.LT) {
      return _skipLTGT(next);
    }

    if (!funcFound) {
      return current.next;
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

  void _tryParseConstVar(Token nextToken, AssetFile asset) {
    Token? currentToken = nextToken;
    // Skip type information to get to the variable name
    while (currentToken != null && currentToken.type != TokenType.SEMICOLON) {
      if (currentToken.isIdentifier) {
        var afterIdentifier = currentToken.next;
        if (afterIdentifier != null && (afterIdentifier.type == TokenType.EQ)) {
          if (currentToken.lexeme.isNotEmpty && currentToken.lexeme[0] != '_') {
            results.addDeclaration(currentToken.lexeme, asset, IdentifierType.$variable);
          }
          break;
        }
      }
      currentToken = currentToken.next;
    }
  }

  (DirectiveStatement?, Token? endToken) _tryParseDirective(TokenType type, Token token, AssetFile enclosingAsset) {
    final lexeme = token.lexeme;
    if (lexeme.length < 3) {
      return (null, _skipUntil(token, TokenType.SEMICOLON));
    }
    final url = lexeme.substring(1, lexeme.length - 1);
    final uri = Uri.parse(url);
    if (uri.path[0] == '_') return (null, _skipUntil(token, TokenType.SEMICOLON));

    final asset = fileResolver.buildAssetUri(uri, relativeTo: enclosingAsset);

    Token? current = token.next;
    // Extract show/hide combinators
    final show = <String>[];
    final hide = <String>[];
    var showMode = true;
    var skipNext = false;

    for (current; current != null && !current.isEof; current = current.next) {
      if (skipNext) {
        skipNext = false;
        continue;
      }
      if (current.type == TokenType.AS) {
        skipNext = true;
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

    return (DirectiveStatement(type: type, asset: asset, show: show, hide: hide), current);
  }

  Token? parseTypeDef(Token? token, AssetFile asset) {
    final identifiers = <Token>[];
    int scopeTracker = 0;
    while (token != null && token.type != TokenType.EOF) {
      token = _skipLTGT(token);
      token = _skipParenthesis(token);
      if (scopeTracker == 0 && (token.isIdentifier || token.type == TokenType.EQ)) {
        identifiers.add(token);
      }
      if (token.type == TokenType.SEMICOLON) {
        token = token.next;
        break;
      }
      token = token.next;
    }

    final eqIndex = identifiers.indexWhere((e) => e.type == TokenType.EQ);
    final nameLexeme = eqIndex > 0 ? identifiers[eqIndex - 1].lexeme : identifiers.lastOrNull?.lexeme;
    if (_isValidName(nameLexeme)) {
      results.addDeclaration(nameLexeme!, asset, IdentifierType.$typeAlias);
    }

    return token;
  }

  bool _isValidName(String? identifier) {
    return identifier != null && identifier.isNotEmpty && identifier[0] != '_';
  }

  Token _skipUntil(Token current, TokenType until) {
    while (current.type != until && !current.isEof) {
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

  Token _skipParenthesis(Token token) {
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
