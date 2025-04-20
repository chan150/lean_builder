import 'dart:collection';

/// a simple cache that uses to units as key, one for the source and one for the target
class SourceBasedCache<T> {
  final HashMap<String, Map<String, T>> _cache = HashMap();

  /// Adds a value to the cache for the given source and target.
  T cache(String source, String target, T value) {
    return _cache.putIfAbsent(source, () => {})[target] = value;
  }

  /// Retrieves a value from the cache for the given source and target.
  T? get(String source, String target) {
    return _cache[source]?[target];
  }

  /// Checks if a value exists in the cache for the given source and target.
  bool contains(CompoundKey key) {
    return _cache[key.source]?.containsKey(key.source) ?? false;
  }

  /// Checks if a value exists in the cache for the given source.
  bool containsSource(String source) {
    return _cache.containsKey(source);
  }

  /// Checks if a value exists in the cache for the given source and target.
  bool containsTarget(String source, String target) {
    return _cache[source]?.containsKey(target) ?? false;
  }

  /// Removes a value from the cache for the given source and target.
  CompoundKey keyFor(String source, String target) {
    return CompoundKey(source, target);
  }

  operator [](CompoundKey key) {
    return _cache[key.source]?[key.target];
  }

  T putIfAbsent(CompoundKey key, T Function() value) {
    return _cache.putIfAbsent(key.source, () => {})[key.target] ??= value();
  }

  /// Removes a value from the cache for the given source and target.
  T cacheKey(CompoundKey key, T value) {
    return cache(key.source, key.target, value);
  }

  void remove(CompoundKey key) {
    if (_cache.containsKey(key.source)) {
      _cache[key.source]?.remove(key.target);
      if (_cache[key.source]?.isEmpty ?? true) {
        _cache.remove(key.source);
      }
    }
  }
}

class CompoundKey {
  final String source;
  final String target;

  const CompoundKey(this.source, this.target);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CompoundKey && runtimeType == other.runtimeType && source == other.source && target == other.target;

  @override
  int get hashCode => source.hashCode ^ target.hashCode;
}
