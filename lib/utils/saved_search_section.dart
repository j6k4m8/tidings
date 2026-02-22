import 'package:flutter/material.dart';

import '../models/folder_models.dart';
import '../state/saved_searches.dart';
import '../state/send_queue.dart';

/// Path prefix for saved-search folder items.
/// Full path format: `SEARCH_RESULTS:<query string>`
const String kSavedSearchPathPrefix = '$kSearchFolderPath:';

/// Encodes a saved search query into a FolderItem path.
String savedSearchPath(String query) => '$kSavedSearchPathPrefix$query';

/// Decodes the query string from a saved-search folder path.
/// Returns null if [path] is not a saved-search path.
String? queryFromSavedSearchPath(String path) {
  if (!path.startsWith(kSavedSearchPathPrefix)) return null;
  return path.substring(kSavedSearchPathPrefix.length);
}

/// Returns [sections] with a "Saved Searches" section appended when
/// [store] has at least one saved search.
///
/// Saved searches that are pinned appear first in the list.
List<FolderSection> withSavedSearchesSection(
  List<FolderSection> sections,
  SavedSearchesStore store,
) {
  final allSearches = store.items;
  if (allSearches.isEmpty) return sections;

  final ordered = [
    ...allSearches.where((s) => s.pinned),
    ...allSearches.where((s) => !s.pinned),
  ];

  final items = ordered.map((s) {
    return FolderItem(
      // Use a stable negative index outside the range used by real folders.
      // The home screen resolves saved searches by path, not index.
      index: -100,
      name: s.name,
      path: savedSearchPath(s.query),
      icon: s.pinned ? Icons.push_pin_rounded : Icons.search_rounded,
    );
  }).toList();

  return [
    ...sections,
    FolderSection(
      title: 'Saved Searches',
      kind: FolderSectionKind.savedSearches,
      items: items,
    ),
  ];
}
