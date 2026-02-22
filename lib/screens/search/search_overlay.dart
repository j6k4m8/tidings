import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/account_models.dart';
import '../../search/search_query.dart';
import '../../state/saved_searches.dart';
import '../../theme/color_tokens.dart';
import '../../theme/glass.dart';
import 'search_suggestions.dart';
import 'token_coloring_controller.dart';

/// Shows the full-screen search overlay and resolves to a [SearchQuery]
/// when the user commits, or null if they cancel.
Future<SearchQuery?> showSearchOverlay(
  BuildContext context, {
  required Color accent,
  required List<EmailAccount> accounts,
  required SavedSearchesStore savedSearches,
  String initialQuery = '',
}) {
  return Navigator.of(context).push<SearchQuery>(
    PageRouteBuilder(
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 180),
      reverseTransitionDuration: const Duration(milliseconds: 140),
      pageBuilder: (context, animation, _) => FadeTransition(
        opacity: animation,
        child: _SearchOverlay(
          accent: accent,
          accounts: accounts,
          savedSearches: savedSearches,
          initialQuery: initialQuery,
        ),
      ),
    ),
  );
}

class _SearchOverlay extends StatefulWidget {
  const _SearchOverlay({
    required this.accent,
    required this.accounts,
    required this.savedSearches,
    required this.initialQuery,
  });

  final Color accent;
  final List<EmailAccount> accounts;
  final SavedSearchesStore savedSearches;
  final String initialQuery;

  @override
  State<_SearchOverlay> createState() => _SearchOverlayState();
}

class _SearchOverlayState extends State<_SearchOverlay> {
  late final TokenColoringController _controller;
  final FocusNode _focusNode = FocusNode();
  int _selectedSuggestion = 0;
  List<SearchSuggestion> _suggestions = [];

  @override
  void initState() {
    super.initState();
    _controller = TokenColoringController(accent: widget.accent)
      ..text = widget.initialQuery;
    _controller.addListener(_onQueryChanged);
    widget.savedSearches.addListener(_onQueryChanged);
    // Focus after the Hero/route animation completes so the TextField
    // actually receives input. Using a status listener avoids the race
    // between addPostFrameCallback and the 180ms transition.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onQueryChanged();
      final route = ModalRoute.of(context);
      if (route == null) {
        _requestFocus();
        return;
      }
      void onStatus(AnimationStatus status) {
        if (status == AnimationStatus.completed) {
          route.animation?.removeStatusListener(onStatus);
          _requestFocus();
        }
      }
      if (route.animation?.status == AnimationStatus.completed) {
        _requestFocus();
      } else {
        route.animation?.addStatusListener(onStatus);
      }
    });
  }

  void _requestFocus() {
    if (!mounted) return;
    _focusNode.requestFocus();
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_onQueryChanged);
    widget.savedSearches.removeListener(_onQueryChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    final suggestions = buildSuggestions(
      query: _controller.text,
      accounts: widget.accounts,
      savedSearches: widget.savedSearches,
    );
    setState(() {
      _suggestions = suggestions;
      _selectedSuggestion = 0;
    });
  }

  void _commit([String? overrideQuery]) {
    final raw = overrideQuery ?? _controller.text.trim();
    if (raw.isEmpty) {
      Navigator.of(context).pop(null);
      return;
    }
    final query = SearchQuery.parse(raw);
    Navigator.of(context).pop(query);
  }

  void _selectSuggestion(SearchSuggestion suggestion) {
    _controller.text = suggestion.completion;
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
    // If the completion ends with a colon (field:), keep overlay open for value
    if (!suggestion.completion.trimRight().endsWith(':')) {
      _commit(suggestion.completion);
    }
  }

  void _moveSuggestion(int delta) {
    if (_suggestions.isEmpty) return;
    setState(() {
      _selectedSuggestion = (_selectedSuggestion + delta).clamp(
        0,
        _suggestions.length - 1,
      );
    });
  }

  KeyEventResult _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      _moveSuggestion(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _moveSuggestion(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.tab) {
      if (_suggestions.isNotEmpty) {
        final s = _suggestions[_selectedSuggestion];
        _controller.text = s.completion;
        _controller.selection = TextSelection.collapsed(
          offset: _controller.text.length,
        );
        _onQueryChanged();
        return KeyEventResult.handled;
      }
    }
    if (key == LogicalKeyboardKey.enter) {
      if (_suggestions.isNotEmpty &&
          _suggestions[_selectedSuggestion].completion !=
              _controller.text.trim()) {
        _selectSuggestion(_suggestions[_selectedSuggestion]);
      } else {
        _commit();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop(null);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    final topInset = MediaQuery.of(context).padding.top;
    return Material(
      type: MaterialType.transparency,
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, topInset + 8, 16, 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: KeyboardListener(
              focusNode: FocusNode(skipTraversal: true),
              onKeyEvent: (e) {
                _handleKey(e);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Search field ─────────────────────────────────────
                  Hero(
                    tag: 'search-bar',
                    flightShuttleBuilder: (_, animation, __, fromCtx, toCtx) {
                      final radius = BorderRadiusTween(
                        begin: BorderRadius.circular(18),
                        end: BorderRadius.circular(16),
                      ).evaluate(animation)!;
                      return Material(
                        type: MaterialType.transparency,
                        child: AnimatedBuilder(
                          animation: animation,
                          builder: (_, __) => Container(
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.12)
                                  : Colors.white.withValues(alpha: 0.9),
                              borderRadius: radius,
                              border: Border.all(
                                color: scheme.onSurface.withValues(alpha: 0.1),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    child: GlassPanel(
                      borderRadius: BorderRadius.circular(16),
                      padding: EdgeInsets.zero,
                      variant: GlassVariant.sheet,
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyLarge?.copyWith(letterSpacing: 0),
                        decoration: InputDecoration(
                          hintText:
                              'Search  ·  try  from:you  is:unread  before:1w',
                          hintStyle: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: scheme.onSurface.withValues(alpha: 0.38),
                                letterSpacing: 0,
                              ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            size: 20,
                          ),
                          suffixIcon: _controller.text.isNotEmpty
                              ? IconButton(
                                  onPressed: () {
                                    _controller.clear();
                                    _focusNode.requestFocus();
                                  },
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                  ),
                                )
                              : null,
                          isDense: false,
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 4,
                          ),
                        ),
                        onSubmitted: (_) => _commit(),
                        textInputAction: TextInputAction.search,
                      ),
                    ),
                  ),

                  // ── Suggestions dropdown ─────────────────────────────────
                  if (_suggestions.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    GlassPanel(
                      borderRadius: BorderRadius.circular(16),
                      padding: EdgeInsets.zero,
                      variant: GlassVariant.sheet,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 360),
                          child: ListView.builder(
                            shrinkWrap: true,
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            itemCount: _suggestions.length,
                            itemBuilder: (context, i) {
                              final s = _suggestions[i];
                              final selected = i == _selectedSuggestion;
                              return _SuggestionRow(
                                suggestion: s,
                                selected: selected,
                                accent: widget.accent,
                                onTap: () => _selectSuggestion(s),
                                savedSearches: widget.savedSearches,
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],

                  // ── Save search hint (when query is non-trivial) ─────────
                  if (_controller.text.trim().isNotEmpty &&
                      _suggestions
                          .where(
                            (s) =>
                                s.kind == SuggestionKind.savedSearch &&
                                s.completion == _controller.text.trim(),
                          )
                          .isEmpty) ...[
                    const SizedBox(height: 6),
                    _SaveSearchHint(
                      query: _controller.text.trim(),
                      accent: widget.accent,
                      savedSearches: widget.savedSearches,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Suggestion row ────────────────────────────────────────────────────────────

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({
    required this.suggestion,
    required this.selected,
    required this.accent,
    required this.onTap,
    required this.savedSearches,
  });

  final SearchSuggestion suggestion;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;
  final SavedSearchesStore savedSearches;

  IconData get _icon => switch (suggestion.kind) {
    SuggestionKind.savedSearch => Icons.bookmark_rounded,
    SuggestionKind.field => Icons.label_outline_rounded,
    SuggestionKind.fieldValue => Icons.tag_rounded,
    SuggestionKind.operator_ => Icons.code_rounded,
    SuggestionKind.account => Icons.person_outline_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.12) : Colors.transparent,
        ),
        child: Row(
          children: [
            Icon(
              _icon,
              size: 15,
              color: selected
                  ? accent
                  : ColorTokens.textSecondary(context, 0.5),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    suggestion.label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: selected
                          ? scheme.onSurface
                          : scheme.onSurface.withValues(alpha: 0.85),
                      fontWeight: selected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                  if (suggestion.subtitle.isNotEmpty)
                    Text(
                      suggestion.subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: ColorTokens.textSecondary(context, 0.6),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (selected)
              Icon(
                Icons.arrow_forward_rounded,
                size: 14,
                color: accent.withValues(alpha: 0.7),
              ),
            if (suggestion.kind == SuggestionKind.savedSearch)
              _SavedSearchActions(
                query: suggestion.completion,
                savedSearches: savedSearches,
                accent: accent,
              ),
          ],
        ),
      ),
    );
  }
}

// ── Saved search delete action ────────────────────────────────────────────────

class _SavedSearchActions extends StatelessWidget {
  const _SavedSearchActions({
    required this.query,
    required this.savedSearches,
    required this.accent,
  });

  final String query;
  final SavedSearchesStore savedSearches;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final match = savedSearches.items
        .where((s) => s.query == query)
        .firstOrNull;
    if (match == null) return const SizedBox.shrink();
    return IconButton(
      onPressed: () => savedSearches.remove(match.id),
      icon: const Icon(Icons.delete_outline_rounded, size: 15),
      color: ColorTokens.textSecondary(context, 0.5),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 28, height: 28),
      tooltip: 'Remove saved search',
    );
  }
}

// ── Save search hint ──────────────────────────────────────────────────────────

class _SaveSearchHint extends StatefulWidget {
  const _SaveSearchHint({
    required this.query,
    required this.accent,
    required this.savedSearches,
  });

  final String query;
  final Color accent;
  final SavedSearchesStore savedSearches;

  @override
  State<_SaveSearchHint> createState() => _SaveSearchHintState();
}

class _SaveSearchHintState extends State<_SaveSearchHint> {
  bool _expanded = false;
  bool _saving = false;
  late final TextEditingController _nameController;
  late final FocusNode _nameFocus;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.query);
    _nameFocus = FocusNode();
  }

  @override
  void didUpdateWidget(_SaveSearchHint oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset if the query changes while not expanded.
    if (oldWidget.query != widget.query && !_expanded) {
      _nameController.text = widget.query;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  void _expand() {
    setState(() {
      _expanded = true;
      _nameController.text = widget.query;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _nameFocus.requestFocus();
      _nameController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _nameController.text.length,
      );
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    await widget.savedSearches.create(
      name: name,
      query: widget.query,
    );
    if (mounted) setState(() { _saving = false; _expanded = false; });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassPanel(
      borderRadius: BorderRadius.circular(16),
      padding: EdgeInsets.zero,
      variant: GlassVariant.sheet,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        child: _expanded ? _buildExpanded(context, scheme) : _buildCollapsed(context, scheme),
      ),
    );
  }

  Widget _buildCollapsed(BuildContext context, ColorScheme scheme) {
    return InkWell(
      onTap: _expand,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.bookmark_add_outlined, size: 15, color: widget.accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Save  "${widget.query}"',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.75),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 15,
              color: scheme.onSurface.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpanded(BuildContext context, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header row ──────────────────────────────────────────────────
          Row(
            children: [
              Icon(Icons.bookmark_add_rounded, size: 14, color: widget.accent),
              const SizedBox(width: 6),
              Text(
                'Save search',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: widget.accent,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => setState(() => _expanded = false),
                icon: const Icon(Icons.close_rounded, size: 14),
                color: scheme.onSurface.withValues(alpha: 0.35),
                tooltip: 'Cancel',
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints.tightFor(width: 24, height: 24),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // ── Name field + save button ─────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: widget.accent.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                  ),
                  child: TextField(
                    controller: _nameController,
                    focusNode: _nameFocus,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurface,
                    ),
                    decoration: InputDecoration.collapsed(
                      hintText: 'Name this search…',
                      hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.38),
                      ),
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _save(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (_saving)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(widget.accent),
                  ),
                )
              else
                FilledButton(
                  onPressed: _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: widget.accent,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Save',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
