import 'package:analyzer/dart/ast/ast.dart';

class IgnoringAstVisitor<R> implements AstVisitor<R> {
  /// Initialize a newly created visitor.
  const IgnoringAstVisitor();

  @override
  R? visitAdjacentStrings(AdjacentStrings node) => _ignore(node);

  @override
  R? visitAnnotation(Annotation node) => _ignore(node);

  @override
  R? visitArgumentList(ArgumentList node) => _ignore(node);

  @override
  R? visitAsExpression(AsExpression node) => _ignore(node);

  @override
  R? visitAssertInitializer(AssertInitializer node) => _ignore(node);

  @override
  R? visitAssertStatement(AssertStatement node) => _ignore(node);

  @override
  R? visitAssignedVariablePattern(AssignedVariablePattern node) => _ignore(node);

  @override
  R? visitAssignmentExpression(AssignmentExpression node) => _ignore(node);

  @override
  R? visitAugmentedExpression(AugmentedExpression node) => _ignore(node);

  @override
  R? visitAugmentedInvocation(AugmentedInvocation node) => _ignore(node);

  @override
  R? visitAwaitExpression(AwaitExpression node) => _ignore(node);

  @override
  R? visitBinaryExpression(BinaryExpression node) => _ignore(node);

  @override
  R? visitBlock(Block node) => _ignore(node);

  @override
  R? visitBlockFunctionBody(BlockFunctionBody node) => _ignore(node);

  @override
  R? visitBooleanLiteral(BooleanLiteral node) => _ignore(node);

  @override
  R? visitBreakStatement(BreakStatement node) => _ignore(node);

  @override
  R? visitCascadeExpression(CascadeExpression node) => _ignore(node);

  @override
  R? visitCaseClause(CaseClause node) => _ignore(node);

  @override
  R? visitCastPattern(CastPattern node) => _ignore(node);

  @override
  R? visitCatchClause(CatchClause node) => _ignore(node);

  @override
  R? visitCatchClauseParameter(CatchClauseParameter node) => _ignore(node);

  @override
  R? visitClassDeclaration(ClassDeclaration node) => _ignore(node);

  @override
  R? visitClassTypeAlias(ClassTypeAlias node) => _ignore(node);

  @override
  R? visitComment(Comment node) => _ignore(node);

  @override
  R? visitCommentReference(CommentReference node) => _ignore(node);

  @override
  R? visitCompilationUnit(CompilationUnit node) => _ignore(node);

  @override
  R? visitConditionalExpression(ConditionalExpression node) => _ignore(node);

  @override
  R? visitConfiguration(Configuration node) => _ignore(node);

  @override
  R? visitConstantPattern(ConstantPattern node) => _ignore(node);

  @override
  R? visitConstructorDeclaration(ConstructorDeclaration node) => _ignore(node);

  @override
  R? visitConstructorFieldInitializer(ConstructorFieldInitializer node) => _ignore(node);

  @override
  R? visitConstructorName(ConstructorName node) => _ignore(node);

  @override
  R? visitConstructorReference(ConstructorReference node) => _ignore(node);

  @override
  R? visitConstructorSelector(ConstructorSelector node) => _ignore(node);

  @override
  R? visitContinueStatement(ContinueStatement node) => _ignore(node);

  @override
  R? visitDeclaredIdentifier(DeclaredIdentifier node) => _ignore(node);

  @override
  R? visitDeclaredVariablePattern(DeclaredVariablePattern node) => _ignore(node);

  @override
  R? visitDefaultFormalParameter(DefaultFormalParameter node) => _ignore(node);

  @override
  R? visitDoStatement(DoStatement node) => _ignore(node);

  @override
  R? visitDottedName(DottedName node) => _ignore(node);

  @override
  R? visitDoubleLiteral(DoubleLiteral node) => _ignore(node);

  @override
  R? visitEmptyFunctionBody(EmptyFunctionBody node) => _ignore(node);

  @override
  R? visitEmptyStatement(EmptyStatement node) => _ignore(node);

  @override
  R? visitEnumConstantArguments(EnumConstantArguments node) => _ignore(node);

  @override
  R? visitEnumConstantDeclaration(EnumConstantDeclaration node) => _ignore(node);

  @override
  R? visitEnumDeclaration(EnumDeclaration node) => _ignore(node);

  @override
  R? visitExportDirective(ExportDirective node) => _ignore(node);

  @override
  R? visitExpressionFunctionBody(ExpressionFunctionBody node) => _ignore(node);

  @override
  R? visitExpressionStatement(ExpressionStatement node) => _ignore(node);

  @override
  R? visitExtendsClause(ExtendsClause node) => _ignore(node);

  @override
  R? visitExtensionDeclaration(ExtensionDeclaration node) => _ignore(node);

  @override
  R? visitExtensionOnClause(ExtensionOnClause node) => _ignore(node);

  @override
  R? visitExtensionOverride(ExtensionOverride node) => _ignore(node);

  @override
  R? visitExtensionTypeDeclaration(ExtensionTypeDeclaration node) => _ignore(node);

  @override
  R? visitFieldDeclaration(FieldDeclaration node) => _ignore(node);

  @override
  R? visitFieldFormalParameter(FieldFormalParameter node) => _ignore(node);

  @override
  R? visitForEachPartsWithDeclaration(ForEachPartsWithDeclaration node) => _ignore(node);

  @override
  R? visitForEachPartsWithIdentifier(ForEachPartsWithIdentifier node) => _ignore(node);

  @override
  R? visitForEachPartsWithPattern(ForEachPartsWithPattern node) => _ignore(node);

  @override
  R? visitForElement(ForElement node) => _ignore(node);

  @override
  R? visitFormalParameterList(FormalParameterList node) => _ignore(node);

  @override
  R? visitForPartsWithDeclarations(ForPartsWithDeclarations node) => _ignore(node);

  @override
  R? visitForPartsWithExpression(ForPartsWithExpression node) => _ignore(node);

  @override
  R? visitForPartsWithPattern(ForPartsWithPattern node) => _ignore(node);

  @override
  R? visitForStatement(ForStatement node) => _ignore(node);

  @override
  R? visitFunctionDeclaration(FunctionDeclaration node) => _ignore(node);

  @override
  R? visitFunctionDeclarationStatement(FunctionDeclarationStatement node) => _ignore(node);

  @override
  R? visitFunctionExpression(FunctionExpression node) => _ignore(node);

  @override
  R? visitFunctionExpressionInvocation(FunctionExpressionInvocation node) => _ignore(node);

  @override
  R? visitFunctionReference(FunctionReference node) => _ignore(node);

  @override
  R? visitFunctionTypeAlias(FunctionTypeAlias node) => _ignore(node);

  @override
  R? visitFunctionTypedFormalParameter(FunctionTypedFormalParameter node) => _ignore(node);

  @override
  R? visitGenericFunctionType(GenericFunctionType node) => _ignore(node);

  @override
  R? visitGenericTypeAlias(GenericTypeAlias node) => _ignore(node);

  @override
  R? visitGuardedPattern(GuardedPattern node) => _ignore(node);

  @override
  R? visitHideCombinator(HideCombinator node) => _ignore(node);

  @override
  R? visitIfElement(IfElement node) => _ignore(node);

  @override
  R? visitIfStatement(IfStatement node) => _ignore(node);

  @override
  R? visitImplementsClause(ImplementsClause node) => _ignore(node);

  @override
  R? visitImplicitCallReference(ImplicitCallReference node) => _ignore(node);

  @override
  R? visitImportDirective(ImportDirective node) => _ignore(node);

  @override
  R? visitImportPrefixReference(ImportPrefixReference node) => _ignore(node);

  @override
  R? visitIndexExpression(IndexExpression node) => _ignore(node);

  @override
  R? visitInstanceCreationExpression(InstanceCreationExpression node) => _ignore(node);

  @override
  R? visitIntegerLiteral(IntegerLiteral node) => _ignore(node);

  @override
  R? visitInterpolationExpression(InterpolationExpression node) => _ignore(node);

  @override
  R? visitInterpolationString(InterpolationString node) => _ignore(node);

  @override
  R? visitIsExpression(IsExpression node) => _ignore(node);

  @override
  R? visitLabel(Label node) => _ignore(node);

  @override
  R? visitLabeledStatement(LabeledStatement node) => _ignore(node);

  @override
  R? visitLibraryDirective(LibraryDirective node) => _ignore(node);

  @override
  R? visitLibraryIdentifier(LibraryIdentifier node) => _ignore(node);

  @override
  R? visitListLiteral(ListLiteral node) => _ignore(node);

  @override
  R? visitListPattern(ListPattern node) => _ignore(node);

  @override
  R? visitLogicalAndPattern(LogicalAndPattern node) => _ignore(node);

  @override
  R? visitLogicalOrPattern(LogicalOrPattern node) => _ignore(node);

  @override
  R? visitMapLiteralEntry(MapLiteralEntry node) => _ignore(node);

  @override
  R? visitMapPattern(MapPattern node) => _ignore(node);

  @override
  R? visitMapPatternEntry(MapPatternEntry node) => _ignore(node);

  @override
  R? visitMethodDeclaration(MethodDeclaration node) => _ignore(node);

  @override
  R? visitMethodInvocation(MethodInvocation node) => _ignore(node);

  @override
  R? visitMixinDeclaration(MixinDeclaration node) => _ignore(node);

  @override
  R? visitMixinOnClause(MixinOnClause node) => _ignore(node);

  @override
  R? visitNamedExpression(NamedExpression node) => _ignore(node);

  @override
  R? visitNamedType(NamedType node) => _ignore(node);

  @override
  R? visitNativeClause(NativeClause node) => _ignore(node);

  @override
  R? visitNativeFunctionBody(NativeFunctionBody node) => _ignore(node);

  @override
  R? visitNullAssertPattern(NullAssertPattern node) => _ignore(node);

  @override
  R? visitNullAwareElement(NullAwareElement node) => _ignore(node);

  @override
  R? visitNullCheckPattern(NullCheckPattern node) => _ignore(node);

  @override
  R? visitNullLiteral(NullLiteral node) => _ignore(node);

  @override
  R? visitObjectPattern(ObjectPattern node) => _ignore(node);

  @override
  R? visitParenthesizedExpression(ParenthesizedExpression node) => _ignore(node);

  @override
  R? visitParenthesizedPattern(ParenthesizedPattern node) => _ignore(node);

  @override
  R? visitPartDirective(PartDirective node) => _ignore(node);

  @override
  R? visitPartOfDirective(PartOfDirective node) => _ignore(node);

  @override
  R? visitPatternAssignment(PatternAssignment node) => _ignore(node);

  @override
  R? visitPatternField(PatternField node) => _ignore(node);

  @override
  R? visitPatternFieldName(PatternFieldName node) => _ignore(node);

  @override
  R? visitPatternVariableDeclaration(PatternVariableDeclaration node) => _ignore(node);

  @override
  R? visitPatternVariableDeclarationStatement(PatternVariableDeclarationStatement node) => _ignore(node);

  @override
  R? visitPostfixExpression(PostfixExpression node) => _ignore(node);

  @override
  R? visitPrefixedIdentifier(PrefixedIdentifier node) => _ignore(node);

  @override
  R? visitPrefixExpression(PrefixExpression node) => _ignore(node);

  @override
  R? visitPropertyAccess(PropertyAccess node) => _ignore(node);

  @override
  R? visitRecordLiteral(RecordLiteral node) => _ignore(node);

  @override
  R? visitRecordPattern(RecordPattern node) => _ignore(node);

  @override
  R? visitRecordTypeAnnotation(RecordTypeAnnotation node) => _ignore(node);

  @override
  R? visitRecordTypeAnnotationNamedField(RecordTypeAnnotationNamedField node) => _ignore(node);

  @override
  R? visitRecordTypeAnnotationNamedFields(RecordTypeAnnotationNamedFields node) => _ignore(node);

  @override
  R? visitRecordTypeAnnotationPositionalField(RecordTypeAnnotationPositionalField node) => _ignore(node);

  @override
  R? visitRedirectingConstructorInvocation(RedirectingConstructorInvocation node) => _ignore(node);

  @override
  R? visitRelationalPattern(RelationalPattern node) => _ignore(node);

  @override
  R? visitRepresentationConstructorName(RepresentationConstructorName node) => _ignore(node);

  @override
  R? visitRepresentationDeclaration(RepresentationDeclaration node) => _ignore(node);

  @override
  R? visitRestPatternElement(RestPatternElement node) => _ignore(node);

  @override
  R? visitRethrowExpression(RethrowExpression node) => _ignore(node);

  @override
  R? visitReturnStatement(ReturnStatement node) => _ignore(node);

  @override
  R? visitScriptTag(ScriptTag node) => _ignore(node);

  @override
  R? visitSetOrMapLiteral(SetOrMapLiteral node) => _ignore(node);

  @override
  R? visitShowCombinator(ShowCombinator node) => _ignore(node);

  @override
  R? visitSimpleFormalParameter(SimpleFormalParameter node) => _ignore(node);

  @override
  R? visitSimpleIdentifier(SimpleIdentifier node) => _ignore(node);

  @override
  R? visitSimpleStringLiteral(SimpleStringLiteral node) => _ignore(node);

  @override
  R? visitSpreadElement(SpreadElement node) => _ignore(node);

  @override
  R? visitStringInterpolation(StringInterpolation node) => _ignore(node);

  @override
  R? visitSuperConstructorInvocation(SuperConstructorInvocation node) => _ignore(node);

  @override
  R? visitSuperExpression(SuperExpression node) => _ignore(node);

  @override
  R? visitSuperFormalParameter(SuperFormalParameter node) => _ignore(node);

  @override
  R? visitSwitchCase(SwitchCase node) => _ignore(node);

  @override
  R? visitSwitchDefault(SwitchDefault node) => _ignore(node);

  @override
  R? visitSwitchExpression(SwitchExpression node) => _ignore(node);

  @override
  R? visitSwitchExpressionCase(SwitchExpressionCase node) => _ignore(node);

  @override
  R? visitSwitchPatternCase(SwitchPatternCase node) => _ignore(node);

  @override
  R? visitSwitchStatement(SwitchStatement node) => _ignore(node);

  @override
  R? visitSymbolLiteral(SymbolLiteral node) => _ignore(node);

  @override
  R? visitThisExpression(ThisExpression node) => _ignore(node);

  @override
  R? visitThrowExpression(ThrowExpression node) => _ignore(node);

  @override
  R? visitTopLevelVariableDeclaration(TopLevelVariableDeclaration node) => _ignore(node);

  @override
  R? visitTryStatement(TryStatement node) => _ignore(node);

  @override
  R? visitTypeArgumentList(TypeArgumentList node) => _ignore(node);

  @override
  R? visitTypeLiteral(TypeLiteral node) => _ignore(node);

  @override
  R? visitTypeParameter(TypeParameter node) => _ignore(node);

  @override
  R? visitTypeParameterList(TypeParameterList node) => _ignore(node);

  @override
  R? visitVariableDeclaration(VariableDeclaration node) => _ignore(node);

  @override
  R? visitVariableDeclarationList(VariableDeclarationList node) => _ignore(node);

  @override
  R? visitVariableDeclarationStatement(VariableDeclarationStatement node) => _ignore(node);

  @override
  R? visitWhenClause(WhenClause node) => _ignore(node);

  @override
  R? visitWhileStatement(WhileStatement node) => _ignore(node);

  @override
  R? visitWildcardPattern(WildcardPattern node) => _ignore(node);

  @override
  R? visitWithClause(WithClause node) => _ignore(node);

  @override
  R? visitYieldStatement(YieldStatement node) => _ignore(node);

  R? _ignore(AstNode node) {
    print('Ignoring: $node');
    return null;
  }
}
