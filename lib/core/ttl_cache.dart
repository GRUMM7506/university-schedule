/// A tiny in-memory cache with per-entry time-to-live.
///
/// Used by [AcademicService] to avoid re-fetching reference data (faculties,
/// groups, teachers, etc.) on every screen transition. Each entry expires
/// after [ttl] and is refetched transparently on the next read.
class TtlCache<K, V> {
  TtlCache({this.ttl = const Duration(minutes: 2)});

  final Duration ttl;
  final Map<K, _CacheEntry<V>> _entries = {};

  /// Returns the cached value for [key] if present and not yet expired,
  /// otherwise null.
  V? get(K key) {
    final entry = _entries[key];
    if (entry == null) return null;
    if (DateTime.now().isAfter(entry.expiresAt)) {
      _entries.remove(key);
      return null;
    }
    return entry.value;
  }

  void set(K key, V value) {
    _entries[key] = _CacheEntry(value, DateTime.now().add(ttl));
  }

  /// Removes a single cached key, e.g. after a mutation that affects it.
  void invalidate(K key) => _entries.remove(key);

  /// Clears every cached entry, e.g. after a mutation whose effect on
  /// other cached entries (foreign keys, derived names) is hard to pin down.
  void clear() => _entries.clear();
}

class _CacheEntry<V> {
  _CacheEntry(this.value, this.expiresAt);
  final V value;
  final DateTime expiresAt;
}