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

  void scanFile(AssetSrc asset) {
    try {
      if (results.isVisited(asset.id)) return;
      final bytes = asset.readAsBytesSync();
      results.addAsset(asset);

      var token = fasta.scan(bytes).tokens;
      String? libraryName;
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
              token = nextT ?? nextToken;
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
              if (_isValidName(nextLexeme)) {
                // it could be a class type alias
                nextToken = _skipUntilAny(nextToken, {TokenType.OPEN_CURLY_BRACKET, TokenType.SEMICOLON});
                final type =
                    nextToken.type == TokenType.SEMICOLON
                        ? TopLevelIdentifierType.$typeAlias
                        : TopLevelIdentifierType.$class;
                results.addDeclaration(nextLexeme, asset, type);
              }
              break;
            case Keyword.MIXIN:
            case Keyword.ENUM:
              results.addDeclaration(nextLexeme, asset, TopLevelIdentifierType.fromKeyword(type));
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
              results.addDeclaration(extName, asset, TopLevelIdentifierType.$extension);

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

      if (asset.uri.toString().contains(
        '/Users/milad/Dev/sdk/flutter/bin/cache/dart-sdk/lib/html/dartium/nativewrappers.dart',
      )) {
        print('Scanning file: ${asset.uri}');
      }

      results.updateAssetInfo(asset, content: bytes, hasAnnotation: hasTopLevelAnnotation, libraryName: libraryName);
    } catch (e) {
      print('Error scanning file: ${asset.path}');
      if (e is Error) {
        print(e.stackTrace);
      } else {
        print(StackTrace.current);
      }
      // Silent error handling
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

  Token? _tryParseFunction(Token token, AssetSrc asset) {
    Token? current = _skipLTGT(token);
    current = _skipParenthesis(current);

    bool funcFound = false;
    final next = current.next;
    if (current.type == Keyword.FUNCTION) {
      current = current.next!;
    } else if (next != null && _skipLTGT(next).type == TokenType.OPEN_PAREN) {
      funcFound = true;
      if (_isValidName(current.lexeme)) {
        results.addDeclaration(current.lexeme, asset, TopLevelIdentifierType.$function);
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

  void _tryParseConstVar(Token nextToken, AssetSrc asset) {
    Token? currentToken = nextToken;
    // Skip type information to get to the variable name
    while (currentToken != null && currentToken.type != TokenType.SEMICOLON) {
      if (currentToken.isIdentifier) {
        var afterIdentifier = currentToken.next;
        if (afterIdentifier != null && (afterIdentifier.type == TokenType.EQ)) {
          results.addDeclaration(currentToken.lexeme, asset, TopLevelIdentifierType.$variable);
          break;
        }
      }
      currentToken = currentToken.next;
    }
  }

  (Token?, DirectiveStatement?) _tryParseDirective(TokenType keyword, Token next, AssetSrc enclosingAsset) {
    bool isPartOf = keyword == Keyword.PART && next.type == Keyword.OF;
    String uriString = '';

    Token? current = next.next;

    if (isPartOf) {
      // could be pointing to a library directive which can have chained String Tokens
      if (current?.type == TokenType.STRING) {
        uriString = current!.lexeme;
      } else {
        while (current != null && !current.isEof && current.type != TokenType.SEMICOLON) {
          uriString += current.lexeme;
          current = current.next;
        }
        if (uriString.isNotEmpty) {
          results.addLibraryPartOf(uriString, enclosingAsset);
        }
        return (current, null);
      }
    } else {
      uriString = next.lexeme;
    }

    if (uriString.length < 3) {
      return (_skipUntil(next, TokenType.SEMICOLON), null);
    }

    // remove quotes
    uriString = uriString.substring(1, uriString.length - 1);
    final uri = Uri.parse(uriString);

    // skip private package imports
    if (uri.scheme == 'package' && uri.path.isNotEmpty && uri.path[0] == '_') {
      return (_skipUntil(next, TokenType.SEMICOLON), null);
    }

    final asset = fileResolver.buildAssetUri(uri, relativeTo: enclosingAsset);

    final show = <String>[];
    final hide = <String>[];
    String? prefix;
    var showMode = true;
    for (current; current != null && !current.isEof; current = current.next) {
      if (current.type == TokenType.AS) {
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

    final directive = DirectiveStatement(type: type, asset: asset, show: show, hide: hide, prefix: prefix);
    return (current, directive);
  }

  Token? parseTypeDef(Token? token, AssetSrc asset) {
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
      results.addDeclaration(nameLexeme!, asset, TopLevelIdentifierType.$typeAlias);
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
