import '../../models/account_models.dart';
import '../../search/query_token.dart';
import '../../state/saved_searches.dart';

/// A single suggestion item shown in the search dropdown.
class SearchSuggestion {
  const SearchSuggestion({
    required this.kind,
    required this.label,
    required this.subtitle,
    required this.completion,
  });

  final SuggestionKind kind;

  /// Display name shown in the row.
  final String label;

  /// Secondary line (may be empty).
  final String subtitle;

  /// The text to insert when this suggestion is selected.
  final String completion;
}

enum SuggestionKind {
  savedSearch,
  field,
  fieldValue,
  operator_,
  account,
}

/// Generates contextual suggestions based on the current query text.
List<SearchSuggestion> buildSuggestions({
  required String query,
  required List<EmailAccount> accounts,
  required SavedSearchesStore savedSearches,
}) {
  final trimmed = query.trim();

  // ── Empty query: show saved searches + field starters ──────────────────
  if (trimmed.isEmpty) {
    final saved = savedSearches.items
        .map((s) => SearchSuggestion(
              kind: SuggestionKind.savedSearch,
              label: s.name,
              subtitle: s.query,
              completion: s.query,
            ))
        .toList();
    final fields = _fieldStarters(withColon: true);
    return [...saved, ...fields];
  }

  // ── Detect if cursor is after a known field with no value yet ──────────
  // e.g. "from:" or "from:jo"
  final fieldMatch = RegExp(
    r'(\w+):(\S*)$',
    caseSensitive: false,
  ).firstMatch(trimmed);

  if (fieldMatch != null) {
    final fieldName = fieldMatch.group(1)!.toLowerCase();
    final partial = fieldMatch.group(2)!.toLowerCase();
    if (kQueryFields.contains(fieldName)) {
      final values = _valuesForField(
        fieldName,
        partial: partial,
        accounts: accounts,
      );
      if (values.isNotEmpty) return values;
    }
  }

  // ── Partial or exact field name (user typing "fr" or "from") ─────────
  final lastWord = trimmed.split(RegExp(r'\s+')).last.toLowerCase();
  if (!lastWord.contains(':')) {
    final fieldSuggestions = kQueryFields
        .where((f) => f.startsWith(lastWord))
        .map((f) => SearchSuggestion(
              kind: SuggestionKind.field,
              label: '$f:',
              subtitle: _fieldDescription(f),
              completion: _replaceLastWord(trimmed, '$f:'),
            ))
        .toList();
    if (fieldSuggestions.isNotEmpty) return fieldSuggestions;
  }

  // ── Operator suggestions ───────────────────────────────────────────────
  if (lastWord.isNotEmpty && !lastWord.contains(':')) {
    final ops = <SearchSuggestion>[
      if ('and'.startsWith(lastWord)) _andSuggestion(trimmed),
      if ('or'.startsWith(lastWord)) _orSuggestion(trimmed),
      if ('not'.startsWith(lastWord)) _notSuggestion(trimmed),
    ];
    if (ops.isNotEmpty) return ops;
  }

  // ── Saved searches matching current query ─────────────────────────────
  final matched = savedSearches.items
      .where((s) =>
          s.query.toLowerCase().contains(trimmed.toLowerCase()) ||
          s.name.toLowerCase().contains(trimmed.toLowerCase()))
      .map((s) => SearchSuggestion(
            kind: SuggestionKind.savedSearch,
            label: s.name,
            subtitle: s.query,
            completion: s.query,
          ))
      .toList();
  return matched;
}

// ── Helpers ───────────────────────────────────────────────────────────────

List<SearchSuggestion> _fieldStarters({required bool withColon}) {
  return kQueryFields.map((f) {
    return SearchSuggestion(
      kind: SuggestionKind.field,
      label: '$f:',
      subtitle: _fieldDescription(f),
      completion: '$f:',
    );
  }).toList();
}

List<SearchSuggestion> _valuesForField(
  String field,
  {required String partial,
  required List<EmailAccount> accounts}) {
  switch (field) {
    case 'is':
      return _filterValues(
        partial,
        values: ['unread', 'read', 'starred', 'unstarred', 'me', 'sent'],
        field: field,
        kind: SuggestionKind.fieldValue,
      );
    case 'has':
      return _filterValues(
        partial,
        values: ['attachment', 'link'],
        field: field,
        kind: SuggestionKind.fieldValue,
      );
    case 'in':
      return _filterValues(
        partial,
        values: ['inbox', 'sent', 'drafts', 'trash', 'spam', 'archive'],
        field: field,
        kind: SuggestionKind.fieldValue,
      );
    case 'account':
      return accounts
          .where((a) =>
              a.email.toLowerCase().contains(partial) ||
              a.displayName.toLowerCase().contains(partial))
          .map((a) => SearchSuggestion(
                kind: SuggestionKind.account,
                label: a.displayName,
                subtitle: partial.isEmpty
                    ? a.email
                    : '${partial.isEmpty ? '' : '(partial match) '}${a.email}',
                completion: 'account:${a.email}',
              ))
          .toList();
    case 'before':
    case 'after':
    case 'date':
      return _filterValues(
        partial,
        values: ['today', 'yesterday', '1d', '1w', '1mo', '3mo', '6mo', '1y'],
        field: field,
        kind: SuggestionKind.fieldValue,
      );
    default:
      return [];
  }
}

List<SearchSuggestion> _filterValues(
  String partial, {
  required List<String> values,
  required String field,
  required SuggestionKind kind,
}) {
  return values
      .where((v) => partial.isEmpty || v.startsWith(partial))
      .map((v) => SearchSuggestion(
            kind: kind,
            label: '$field:$v',
            subtitle: '',
            completion: '$field:$v',
          ))
      .toList();
}

String _fieldDescription(String field) => switch (field) {
      'from' => 'Filter by sender',
      'to' => 'Filter by recipient',
      'cc' => 'Filter by CC',
      'bcc' => 'Filter by BCC',
      'subject' => 'Filter by subject line',
      'before' => 'Received before date',
      'after' => 'Received after date',
      'date' => 'Received on date',
      'account' => 'Filter by account',
      'in' => 'Filter by folder',
      'label' => 'Filter by label',
      'has' => 'Has attachment or link',
      'is' => 'Message state (unread, starred…)',
      _ => '',
    };

String _replaceLastWord(String text, String replacement) {
  final parts = text.split(RegExp(r'\s+'));
  parts[parts.length - 1] = replacement;
  return parts.join(' ');
}

SearchSuggestion _andSuggestion(String text) => SearchSuggestion(
      kind: SuggestionKind.operator_,
      label: 'AND',
      subtitle: 'Both conditions must match',
      completion: _replaceLastWord(text, 'AND '),
    );

SearchSuggestion _orSuggestion(String text) => SearchSuggestion(
      kind: SuggestionKind.operator_,
      label: 'OR',
      subtitle: 'Either condition must match',
      completion: _replaceLastWord(text, 'OR '),
    );

SearchSuggestion _notSuggestion(String text) => SearchSuggestion(
      kind: SuggestionKind.operator_,
      label: 'NOT',
      subtitle: 'Exclude matching messages',
      completion: _replaceLastWord(text, 'NOT '),
    );
