import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'config_store.dart';

/// A single saved search with a display name and query string.
@immutable
class SavedSearch {
  const SavedSearch({
    required this.id,
    required this.name,
    required this.query,
    this.pinned = false,
  });

  final String id;
  final String name;
  final String query;
  final bool pinned;

  SavedSearch copyWith({String? name, String? query, bool? pinned}) {
    return SavedSearch(
      id: id,
      name: name ?? this.name,
      query: query ?? this.query,
      pinned: pinned ?? this.pinned,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'query': query,
    'pinned': pinned,
  };

  factory SavedSearch.fromJson(Map<String, Object?> json) => SavedSearch(
    id: json['id'] as String? ?? _newId(),
    name: json['name'] as String? ?? '',
    query: json['query'] as String? ?? '',
    pinned: json['pinned'] as bool? ?? false,
  );
}

String _newId() =>
    DateTime.now().microsecondsSinceEpoch.toRadixString(36);

/// Persists and manages saved searches.
///
/// Stored at `~/.config/tidings/saved_searches.json`.
class SavedSearchesStore extends ChangeNotifier {
  SavedSearchesStore._();
  static final instance = SavedSearchesStore._();

  final List<SavedSearch> _items = [];
  bool _loaded = false;

  List<SavedSearch> get items => List.unmodifiable(_items);
  List<SavedSearch> get pinned =>
      _items.where((s) => s.pinned).toList();
  List<SavedSearch> get unpinned =>
      _items.where((s) => !s.pinned).toList();

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    await _load();
  }

  Future<void> add(SavedSearch search) async {
    _items.removeWhere((s) => s.id == search.id);
    _items.add(search);
    notifyListeners();
    await _save();
  }

  Future<void> update(SavedSearch search) async {
    final idx = _items.indexWhere((s) => s.id == search.id);
    if (idx < 0) return;
    _items[idx] = search;
    notifyListeners();
    await _save();
  }

  Future<void> remove(String id) async {
    _items.removeWhere((s) => s.id == id);
    notifyListeners();
    await _save();
  }

  Future<void> togglePin(String id) async {
    final idx = _items.indexWhere((s) => s.id == id);
    if (idx < 0) return;
    _items[idx] = _items[idx].copyWith(pinned: !_items[idx].pinned);
    notifyListeners();
    await _save();
  }

  /// Creates and saves a new search. Returns the new [SavedSearch].
  Future<SavedSearch> create({required String name, required String query}) async {
    final search = SavedSearch(id: _newId(), name: name, query: query);
    await add(search);
    return search;
  }

  // ── Persistence ──────────────────────────────────────────────────────────

  Future<File?> _file() async {
    final dir = await TidingsConfigStore.configDirectory();
    if (dir == null) return null;
    if (!await dir.exists()) await dir.create(recursive: true);
    return File('${dir.path}/saved_searches.json');
  }

  Future<void> _load() async {
    try {
      final file = await _file();
      if (file == null || !await file.exists()) return;
      final content = await file.readAsString();
      final data = jsonDecode(content) as List<dynamic>?;
      if (data == null) return;
      _items.clear();
      for (final item in data) {
        if (item is Map<String, Object?>) {
          _items.add(SavedSearch.fromJson(item));
        }
      }
      notifyListeners();
    } catch (_) {
      // Corrupt file — start fresh.
    }
  }

  Future<void> _save() async {
    try {
      final file = await _file();
      if (file == null) return;
      final json = jsonEncode(_items.map((s) => s.toJson()).toList());
      await file.writeAsString(json);
    } catch (_) {}
  }
}
