class TypeRef {
  final String name;
  final String srcHash;
  final String srcPath;

  TypeRef(this.name, this.srcHash, this.srcPath);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TypeRef &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          srcHash == other.srcHash &&
          srcPath == other.srcPath;

  @override
  int get hashCode => name.hashCode ^ srcHash.hashCode ^ srcPath.hashCode;
}

class TypeResolver {
  final Map<String, TypeRef> _typeRefs = {};

  TypeResolver();

  TypeRef? resolveType(String name) => _typeRefs[name];

  void addTypeRef(String name, String srcHash, String srcPath) {
    _typeRefs[name] = TypeRef(name, srcHash, srcPath);
  }
}
