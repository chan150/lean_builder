import 'dart:convert';
import 'dart:math';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/error/listener.dart';
// ignore: implementation_imports
import 'package:analyzer/src/dart/scanner/reader.dart';
// ignore: implementation_imports
import 'package:analyzer/src/dart/scanner/scanner.dart';
// ignore: implementation_imports
import 'package:analyzer/src/string_source.dart';
import 'package:code_genie/src/resolvers/package_file_resolver.dart';

import '../resolvers/file_asset.dart';
import 'assets_graph.dart';
import 'directive_statement.dart';

class TopLevelScanner {
  final AssetsGraph graph;
  final PackageFileResolver fileResolver;

  TopLevelScanner(this.graph, this.fileResolver);

  static const _declarationKeywords = {Keyword.CLASS, Keyword.MIXIN, Keyword.ENUM, Keyword.TYPEDEF, Keyword.EXTENSION};

  void scanFile(FileAsset asset) {
    try {
      if (graph.isVisited(asset.id)) return;
      final bytes = asset.readAsBytesSync();
      final content = utf8.decode(bytes);
      graph.addAsset(asset);
      final scanner = Scanner(StringSource(content, asset.path), CharSequenceReader(content), BooleanErrorListener())
        ..configureFeatures(
          featureSetForOverriding: FeatureSet.latestLanguageVersion(),
          featureSet: FeatureSet.latestLanguageVersion(),
        );

      var token = scanner.tokenize(reportScannerErrors: false);
      final exports = <DirectiveStatement>{};
      final imports = <DirectiveStatement>{};

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
              if (type == Keyword.EXPORT || (type == Keyword.PART && nextToken.type != Keyword.OF)) {
                final directive = _tryParseDirective(nextToken, asset);
                if (directive != null) exports.add(directive);
              } else if (type == Keyword.IMPORT) {
                final directive = _tryParseDirective(nextToken, asset);
                if (directive != null) imports.add(directive);
              } else if (nextLexeme[0] != '_' && _declarationKeywords.contains(type)) {
                graph.addDeclaration(nextLexeme, asset);
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
      graph.updateFileInfo(asset, content: bytes, hasAnnotation: hasTopLevelAnnotation);

      for (final export in exports) {
        graph.addExport(asset, export);
        // scanFile(export.asset);
      }

      for (final import in imports) {
        graph.addImport(asset, import);
      }
    } catch (e) {
      // if (e is Error) {
      //   print(e.stackTrace);
      // } else {
      //   print(StackTrace.current);
      // }
      print('Error scanning file: ${asset.shortPath} $e');
      // Silent error handling
    }
  }

  void _tryParseFunction(Token nextToken, Token token, FileAsset asset) {
    // Detect function declarations - look for identifiers followed by (
    var possibleFunctionName = nextToken;
    var afterIdentifier = possibleFunctionName.next;

    // Simple function detection: identifier followed by (
    if (afterIdentifier != null &&
        (afterIdentifier.type == TokenType.OPEN_PAREN ||
            (afterIdentifier.type == TokenType.LT && token.type != TokenType.SEMICOLON))) {
      // Found a function or generic function
      if (possibleFunctionName.lexeme.isNotEmpty && possibleFunctionName.lexeme[0] != '_') {
        graph.addDeclaration(possibleFunctionName.lexeme, asset);
      }
    }
  }

  void _tryParseConstVar(Token nextToken, FileAsset asset) {
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
            graph.addDeclaration(currentToken.lexeme, asset);
          }
          break;
        }
      }
      currentToken = currentToken.next;
    }
  }

  DirectiveStatement? _tryParseDirective(Token nextToken, FileAsset enclosingAsset) {
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

    return DirectiveStatement(asset: asset, show: show, hide: hide);
  }
}
