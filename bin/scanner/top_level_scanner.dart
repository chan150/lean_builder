import 'dart:io';
import 'dart:math';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/src/dart/scanner/reader.dart';
import 'package:analyzer/src/dart/scanner/scanner.dart';
import 'package:analyzer/src/string_source.dart';

import '../utils.dart';
import 'assets_graph.dart';
import 'directive_statement.dart';

class TopLevelScanner {
  final AssetsGraph graph;

  TopLevelScanner(this.graph);

  static const _declarationKeywords = {Keyword.CLASS, Keyword.MIXIN, Keyword.ENUM, Keyword.TYPEDEF, Keyword.EXTENSION};

  void scanFile(File file) {
    try {
      if (graph.isVisited(file.path)) return;
      final content = file.readAsStringSyncSafe();
      if (content == null) return;
      print('Scanning: ${file.path.split('/').last}');
      graph.addAsset(file.path);
      final scanner = Scanner(StringSource(content, file.path), CharSequenceReader(content), BooleanErrorListener())
        ..configureFeatures(
          featureSetForOverriding: FeatureSet.latestLanguageVersion(),
          featureSet: FeatureSet.latestLanguageVersion(),
        );

      var token = scanner.tokenize(reportScannerErrors: false);
      final exports = <DirectiveStatement>{};
      final imports = <DirectiveStatement>{};

      bool inTopLevelScope = true;
      int bracesLevel = 0; // {}
      int parensLevel = 0; // ()
      int bracketsLevel = 0; // []
      bool inFunctionParams = false;
      bool hasTopLevelAnnotation = false;

      while (token.type != TokenType.EOF) {
        switch (token.type) {
          case TokenType.OPEN_CURLY_BRACKET:
            bracesLevel++;
            break;
          case TokenType.CLOSE_CURLY_BRACKET:
            bracesLevel = max(0, bracesLevel - 1);
            break;
          case TokenType.OPEN_PAREN:
            parensLevel++;
            if (bracesLevel == 0 && parensLevel == 1) {
              inFunctionParams = true;
            }
            break;
          case TokenType.CLOSE_PAREN:
            if (parensLevel > 0) parensLevel--;
            if (parensLevel == 0) {
              inFunctionParams = false;
            }
            break;
          case TokenType.OPEN_SQUARE_BRACKET:
            bracketsLevel++;
            break;
          case TokenType.CLOSE_SQUARE_BRACKET:
            if (bracketsLevel > 0) bracketsLevel--;
            break;
          case TokenType.AT:
            if (bracesLevel == 0) {
              hasTopLevelAnnotation = true;
            }
            break;
        }

        inTopLevelScope = bracesLevel == 0 && !inFunctionParams;
        final nextToken = token.next!;

        if (inTopLevelScope && token.isTopLevelKeyword) {
          final type = token.type;
          final nextLexeme = nextToken.lexeme;

          // Skip processing if the identifier starts with '_'
          if (nextLexeme.isNotEmpty && nextLexeme[0] != '_') {
            if (type == Keyword.EXPORT || (type == Keyword.PART && nextToken.type != Keyword.OF)) {
              final statement = _parseDirective(nextToken, file);
              exports.add(statement);
            } else if (type == Keyword.IMPORT) {
              final statement = _parseDirective(nextToken, file);
              imports.add(statement);
            } else if (_declarationKeywords.contains(type)) {
              graph.addDeclaration(nextLexeme, file.path);
            }
          }
        } else if (inTopLevelScope && token.type == Keyword.CONST) {
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
                  graph.addDeclaration(currentToken.lexeme, file.path);
                }
                break;
              }
            }
            currentToken = currentToken.next;
          }
        } else if (inTopLevelScope && nextToken.isIdentifier) {
          // Detect function declarations - look for identifiers followed by (
          var possibleFunctionName = nextToken;
          var afterIdentifier = possibleFunctionName.next;

          // Simple function detection: identifier followed by (
          if (afterIdentifier != null &&
              (afterIdentifier.type == TokenType.OPEN_PAREN ||
                  (afterIdentifier.type == TokenType.LT && token.type != TokenType.SEMICOLON))) {
            // Found a function or generic function
            if (possibleFunctionName.lexeme.isNotEmpty && possibleFunctionName.lexeme[0] != '_') {
              graph.addDeclaration(possibleFunctionName.lexeme, file.path);
            }
          }
        }

        token = nextToken;
      }

      graph.updateFileInfo(file.path, content, hasTopLevelAnnotation);

      for (final export in exports) {
        graph.addExport(file.path, export);
        scanFile(File.fromUri(export.uri));
      }

      for (final import in imports) {
        graph.addImport(file.path, import);
      }
    } catch (e) {
      // Silent error handling
    }
  }

  DirectiveStatement _parseDirective(Token nextToken, File file) {
    final nextLexeme = nextToken.lexeme;
    final exportPath = nextLexeme.substring(1, nextToken.length - 1);
    final uri = graph.packageResolver.resolve(Uri.parse(exportPath), relativeTo: file.uri);

    // Extract show/hide combinators
    final show = <String>[];
    final hide = <String>[];
    var showMode = true;

    for (var t = nextToken.next; t != null; t = t.next) {
      if (t.type == Keyword.SHOW) {
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

    return DirectiveStatement(uri: uri, show: show, hide: hide);
  }
}
