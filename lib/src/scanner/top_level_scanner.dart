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

  static const _declarationKeywords = {Keyword.CLASS, Keyword.MIXIN, Keyword.ENUM, Keyword.TYPEDEF, Keyword.EXTENSION};

  void scanFile(AssetFile asset) {
    try {
      if (results.isVisited(asset.id)) return;
      final bytes = asset.readAsBytesSync();
      results.addAsset(asset);
      var token = fasta.scan(bytes).tokens;
      final directives = <DirectiveStatement>{};

      int scopeTracker = 0;
      bool hasTopLevelAnnotation = false;
      while (token.type != TokenType.EOF) {
        switch (token.type) {
          case TokenType.OPEN_CURLY_BRACKET: // '{'
          case TokenType.OPEN_PAREN: // '('
          case TokenType.OPEN_SQUARE_BRACKET: // '['
          case TokenType.STRING_INTERPOLATION_EXPRESSION: // '${'
            scopeTracker++;
            break;
          case TokenType.CLOSE_CURLY_BRACKET: // '}'
          case TokenType.CLOSE_PAREN: // ')'
          case TokenType.CLOSE_SQUARE_BRACKET: // ']'
            scopeTracker = max(0, scopeTracker - 1);
            break;
        }

        final nextToken = token.next!;

        if (scopeTracker == 0) {
          if (token.type == TokenType.AT) {
            hasTopLevelAnnotation = true;
          } else if (token.isTopLevelKeyword) {
            final type = token.type;
            final nextLexeme = nextToken.lexeme;
            // Skip processing if the identifier starts with '_'
            if (nextLexeme.isNotEmpty) {
              if (type == Keyword.EXPORT ||
                  type == Keyword.IMPORT ||
                  (type == Keyword.PART && nextToken.type != Keyword.OF)) {
                final directive = _tryParseDirective(type, nextToken, asset);
                if (directive != null) directives.add(directive);
              } else if (nextLexeme[0] != '_' && _declarationKeywords.contains(type)) {
                results.addDeclaration(nextLexeme, asset);
              }
            }
          } else if (token.type == Keyword.CONST) {
            _tryParseConstVar(nextToken, asset);
          } else if (nextToken.isIdentifier) {
            _tryParseFunction(nextToken, token, asset);
          }
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

  void _tryParseFunction(Token nextToken, Token token, AssetFile asset) {
    // Detect function declarations - look for identifiers followed by (
    var possibleFunctionName = nextToken;
    var afterIdentifier = possibleFunctionName.next;

    // Simple function detection: identifier followed by (
    if (afterIdentifier != null &&
        (afterIdentifier.type == TokenType.OPEN_PAREN ||
            (afterIdentifier.type == TokenType.LT && token.type != TokenType.SEMICOLON))) {
      // Found a function or generic function
      if (possibleFunctionName.lexeme.isNotEmpty && possibleFunctionName.lexeme[0] != '_') {
        results.addDeclaration(possibleFunctionName.lexeme, asset);
      }
    }
  }

  void _tryParseConstVar(Token nextToken, AssetFile asset) {
    Token? currentToken = nextToken;
    // Skip type information to get to the variable name
    while (currentToken != null && currentToken.type != TokenType.SEMICOLON) {
      if (currentToken.isIdentifier) {
        var afterIdentifier = currentToken.next;
        if (afterIdentifier != null &&
            (afterIdentifier.type == TokenType.EQ ||
                afterIdentifier.type == TokenType.SEMICOLON ||
                afterIdentifier.type == TokenType.COMMA)) {
          if (currentToken.lexeme.isNotEmpty && currentToken.lexeme[0] != '_') {
            results.addDeclaration(currentToken.lexeme, asset);
          }
          break;
        }
      }
      currentToken = currentToken.next;
    }
  }

  DirectiveStatement? _tryParseDirective(TokenType type, Token nextToken, AssetFile enclosingAsset) {
    final nextLexeme = nextToken.lexeme;
    if (nextLexeme.length < 3) return null;
    final url = nextLexeme.substring(1, nextLexeme.length - 1);
    final uri = Uri.parse(url);
    if (uri.path[0] == '_') return null;

    final asset = fileResolver.buildAssetUri(uri, relativeTo: enclosingAsset);

    // Extract show/hide combinators
    final show = <String>[];
    final hide = <String>[];
    var showMode = true;
    var skipNext = false;

    for (var t = nextToken.next; t != null; t = t.next) {
      if (skipNext) {
        skipNext = false;
        continue;
      }
      if (t.type == TokenType.AS) {
        skipNext = true;
      } else if (t.type == Keyword.SHOW) {
        showMode = true;
      } else if (t.type == Keyword.HIDE) {
        showMode = false;
      } else if (t.type == TokenType.IDENTIFIER) {
        if (showMode) {
          show.add(t.lexeme);
        } else {
          hide.add(t.lexeme);
        }
      }
      if (t.type == TokenType.SEMICOLON) break;
    }

    return DirectiveStatement(type: type, asset: asset, show: show, hide: hide);
  }
}
