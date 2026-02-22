import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../models/account_models.dart';
import '../models/email_models.dart';
import '../models/folder_models.dart';
import '../providers/email_provider.dart';
import '../providers/unified_email_provider.dart';
import '../search/search_query.dart';
import '../state/app_state.dart';
import '../state/saved_searches.dart';
import '../state/send_queue.dart';
import '../state/tidings_settings.dart';
import '../state/shortcut_definitions.dart';
import '../state/keyboard_shortcut.dart';
import '../theme/glass.dart';
import '../utils/saved_search_section.dart';
import '../widgets/settings/shortcut_recorder.dart';
import '../widgets/tidings_background.dart';
import 'compose/compose_sheet.dart';
import 'compose/compose_utils.dart';
import 'compose/inline_reply_composer.dart';
import 'home/home_utils.dart';
import 'home/home_layouts.dart';
import '../utils/subject_utils.dart';
import '../utils/reply_utils.dart';
import 'home/thread_detail.dart';
import 'keyboard/command_palette.dart';
import '../theme/account_accent.dart';
import 'keyboard/go_to_dialog.dart';
import 'keyboard/move_to_folder_dialog.dart';
import 'keyboard/shortcuts_sheet.dart';
import 'onboarding_screen.dart';
import 'search/search_overlay.dart';
import 'settings/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.appState, required this.accent});

  final AppState appState;
  final Color accent;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _ShortcutIntent extends Intent {
  const _ShortcutIntent(this.action);

  final ShortcutAction action;
}

class _BlurIntent extends Intent {
  const _BlurIntent();
}

enum _HomeScope { list, detail, editor }

class _HomeScreenState extends State<HomeScreen> {
  static final _escapeKey = LogicalKeySet(LogicalKeyboardKey.escape);
  int _selectedThreadIndex = 0;
  int _selectedFolderIndex = 0;
  int _navIndex = 0;
  bool _showSettings = false;
  bool _sidebarCollapsed = false;
  double _threadPanelFraction = 0.58;
  bool _threadPanelOpen = true;
  TidingsSettings? _settings;
  String? _lastAccountId;
  final FocusNode _searchFocusNode = FocusNode(debugLabel: 'ThreadSearchFocus');
  final FocusNode _rootFocusNode = FocusNode(debugLabel: 'RootShortcuts');
  final FocusNode _threadListFocusNode = FocusNode(
    debugLabel: 'ThreadListFocus',
  );
  final FocusNode _threadDetailFocusNode = FocusNode(
    debugLabel: 'ThreadDetailFocus',
  );
  final ScrollController _threadDetailScrollController = ScrollController();
  final InlineReplyController _inlineReplyController = InlineReplyController();
  final Map<String, int> _messageSelectionByThread = {};
  final Map<String, String> _previousFolderPaths = {};
  late final UnifiedEmailProvider _unifiedProvider = UnifiedEmailProvider(
    appState: widget.appState,
  );
  bool _isUnifiedInbox = false;
  bool _startupApplied = false;
  bool _isRefreshing = false;
  bool _compactRailOpen = false;
  bool _compactRailExpanded = false;
  bool _inlineReplyFocused = false;
  SearchQuery? _activeSearch;
  final SavedSearchesStore _savedSearches = SavedSearchesStore.instance;

  @override
  void initState() {
    super.initState();
    _lastAccountId = widget.appState.selectedAccount?.id;
    widget.appState.addListener(_handleAppStateChange);
    widget.appState.setMenuActionHandler(_handleMenuAction);
    FocusManager.instance.addListener(_handleGlobalFocusChange);
    _savedSearches.addListener(_onSavedSearchesChanged);
    _savedSearches.ensureLoaded();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _rootFocusNode.requestFocus();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final settings = context.tidingsSettings;
    if (_settings != settings) {
      _settings?.removeListener(_handleSettingsChange);
      _settings = settings;
      _settings?.addListener(_handleSettingsChange);
    }
    _handleSettingsChange();
  }

  @override
  void dispose() {
    widget.appState.removeListener(_handleAppStateChange);
    widget.appState.setMenuActionHandler(null);
    widget.appState.updateMenuSelection(hasSelection: false, isUnread: false);
    FocusManager.instance.removeListener(_handleGlobalFocusChange);
    _settings?.removeListener(_handleSettingsChange);
    _savedSearches.removeListener(_onSavedSearchesChanged);
    _searchFocusNode.dispose();
    _rootFocusNode.dispose();
    _threadListFocusNode.dispose();
    _threadDetailFocusNode.dispose();
    _threadDetailScrollController.dispose();
    _unifiedProvider.dispose();
    super.dispose();
  }

  KeyEventResult _handleThreadDetailKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    if (!_threadDetailScrollController.hasClients) {
      return KeyEventResult.ignored;
    }
    final position = _threadDetailScrollController.position;
    final viewport = position.viewportDimension;
    double? delta;
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      delta = 48;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      delta = -48;
    } else if (event.logicalKey == LogicalKeyboardKey.pageDown) {
      delta = viewport * 0.9;
    } else if (event.logicalKey == LogicalKeyboardKey.pageUp) {
      delta = -viewport * 0.9;
    }
    if (delta == null || delta == 0) {
      return KeyEventResult.ignored;
    }
    final nextOffset = (position.pixels + delta).clamp(
      0.0,
      position.maxScrollExtent,
    );
    _threadDetailScrollController.animateTo(
      nextOffset,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
    );
    return KeyEventResult.handled;
  }

  void _handleGlobalFocusChange() {
    if (!mounted) {
      return;
    }
    if (FocusManager.instance.primaryFocus == null) {
      _rootFocusNode.requestFocus();
    }
  }

  void _handleInlineReplyFocusChange(bool hasFocus) {
    if (_inlineReplyFocused == hasFocus) {
      return;
    }
    setState(() {
      _inlineReplyFocused = hasFocus;
    });
  }

  void _handleSettingsChange() {
    if (!mounted) {
      return;
    }
    final settings = _settings;
    if (settings == null) {
      return;
    }
    if (_threadPanelFraction != settings.threadPanelFraction ||
        _sidebarCollapsed != settings.sidebarCollapsed) {
      setState(() {
        _threadPanelFraction = settings.threadPanelFraction;
        _sidebarCollapsed = settings.sidebarCollapsed;
      });
    }
    if (!_startupApplied && widget.appState.hasAccounts) {
      _startupApplied = true;
      final startupId = settings.startupAccountId;
      if (startupId == 'unified') {
        _enableUnifiedInbox();
      } else if (startupId != null) {
        final idx = widget.appState.accounts
            .indexWhere((a) => a.id == startupId);
        if (idx != -1) widget.appState.selectAccount(idx);
      }
    }
  }

  void _handleAppStateChange() {
    final currentId = widget.appState.selectedAccount?.id;
    if (currentId != _lastAccountId) {
      setState(() {
        _selectedThreadIndex = 0;
        _selectedFolderIndex = 0;
        _threadPanelOpen = true;
        _showSettings = false;
      });
      if (!_isUnifiedInbox) {
        widget.appState.setAccentAccountId(null);
      }
      _lastAccountId = currentId;
    }
  }

  Future<void> _enableUnifiedInbox() async {
    if (_isUnifiedInbox) {
      return;
    }
    _previousFolderPaths.clear();
    for (final account in widget.appState.accounts) {
      final provider = widget.appState.providerForAccount(account.id);
      if (provider == null) {
        continue;
      }
      _previousFolderPaths[account.id] = provider.selectedFolderPath;
      if (provider.selectedFolderPath != 'INBOX') {
        await provider.selectFolder('INBOX');
      }
    }
    setState(() {
      _isUnifiedInbox = true;
      _selectedThreadIndex = 0;
      _threadPanelOpen = true;
      _showSettings = false;
    });
    await _unifiedProvider.initialize();
    _syncAccentWithSelection(_unifiedProvider);
  }

  Future<void> _disableUnifiedInbox() async {
    if (!_isUnifiedInbox) {
      return;
    }
    for (final entry in _previousFolderPaths.entries) {
      final provider = widget.appState.providerForAccount(entry.key);
      if (provider == null) {
        continue;
      }
      if (provider.selectedFolderPath != entry.value) {
        await provider.selectFolder(entry.value);
      }
    }
    setState(() {
      _isUnifiedInbox = false;
      _selectedThreadIndex = 0;
      _threadPanelOpen = true;
      _showSettings = false;
    });
    widget.appState.setAccentAccountId(null);
  }

  void _syncAccentWithSelection(EmailProvider listProvider) {
    if (!_isUnifiedInbox) {
      widget.appState.setAccentAccountId(null);
      return;
    }
    final threads = listProvider.threads;
    if (threads.isEmpty) {
      widget.appState.setAccentAccountId(null);
      return;
    }
    final index = selectedIndex(_selectedThreadIndex, threads.length);
    final thread = threads[index];
    final account = _unifiedProvider.accountForThread(thread.id);
    widget.appState.setAccentAccountId(account?.id);
  }

  void _handleFolderSelected(EmailProvider provider, int index) {
    // Resolve path from the augmented sections (includes saved searches).
    final augmentedSections = _augmentedFolderSections(provider);
    final path = _folderPathForIndex(augmentedSections, index);

    // Handle saved-search virtual items.
    if (path != null) {
      final searchQuery = queryFromSavedSearchPath(path);
      if (searchQuery != null) {
        final query = SearchQuery.parse(searchQuery);
        setState(() {
          _activeSearch = query;
          _selectedThreadIndex = 0;
          _threadPanelOpen = true;
          _showSettings = false;
        });
        provider.search(query);
        return;
      }
    }

    if (_isUnifiedInbox && path != kOutboxFolderPath && path != 'INBOX') {
      return;
    }
    setState(() {
      _selectedFolderIndex = index;
      _selectedThreadIndex = 0;
      _threadPanelOpen = true;
      _showSettings = false;
      if (_navIndex == 3) {
        _navIndex = 0;
      }
    });
    if (path != null) {
      provider.selectFolder(path);
    }
  }

  /// Returns provider folder sections augmented with the saved searches section.
  List<FolderSection> _augmentedFolderSections(EmailProvider provider) {
    return withSavedSearchesSection(provider.folderSections, _savedSearches);
  }

  void _onSavedSearchesChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _handleSearchTap(EmailProvider provider) async {
    final result = await showSearchOverlay(
      context,
      accent: widget.accent,
      accounts: widget.appState.accounts,
      savedSearches: _savedSearches,
      initialQuery: _activeSearch?.rawQuery ?? '',
    );
    if (!mounted) return;
    if (result == null) {
      // Cancelled — clear search if active
      if (_activeSearch != null) {
        setState(() => _activeSearch = null);
        await provider.search(null);
      }
      return;
    }
    setState(() => _activeSearch = result);
    await provider.search(result);
  }

  void _clearSearch(EmailProvider provider) {
    setState(() => _activeSearch = null);
    provider.search(null);
  }

  void _openOutbox(EmailProvider provider) {
    final index = _folderIndexForPath(
      provider.folderSections,
      kOutboxFolderPath,
    );
    setState(() {
      if (index != null) {
        _selectedFolderIndex = index;
      }
      _selectedThreadIndex = 0;
      _threadPanelOpen = true;
      _showSettings = false;
      if (_navIndex == 3) {
        _navIndex = 0;
      }
    });
    provider.selectFolder(kOutboxFolderPath);
  }

  // Delegate to the shared home_utils helpers.
  String? _folderPathForIndex(List<FolderSection> sections, int index) =>
      folderPathForIndex(sections, index);

  int? _folderIndexForPath(List<FolderSection> sections, String path) =>
      folderIndexForPath(sections, path);

  String _currentUserEmailForThread(
    EmailThread? thread,
    EmailAccount fallback,
  ) {
    if (!_isUnifiedInbox || thread == null) {
      return fallback.email;
    }
    return _unifiedProvider.accountEmailForThread(thread.id) ?? fallback.email;
  }

  bool _isTextInputFocused() {
    final focus = FocusManager.instance.primaryFocus;
    if (focus == null) return false;
    final ctx = focus.context;
    if (ctx == null) return false;
    if (ctx is Element && !ctx.debugIsActive) return false;
    final widget = ctx.widget;
    if (widget is EditableText || widget is QuillEditor) return true;
    try {
      return ctx.findAncestorWidgetOfExactType<EditableText>() != null ||
          ctx.findAncestorWidgetOfExactType<QuillEditor>() != null ||
          ctx.findAncestorWidgetOfExactType<InlineReplyComposer>() != null;
    } catch (_) {
      return false;
    }
  }

  bool _isShortcutRecorderFocused() {
    final focus = FocusManager.instance.primaryFocus;
    if (focus == null) return false;
    final ctx = focus.context;
    if (ctx == null) return false;
    // Guard against looking up ancestors on a deactivated element.
    if (ctx is Element && !ctx.debugIsActive) return false;
    try {
      return ctx.findAncestorWidgetOfExactType<ShortcutRecorder>() != null;
    } catch (_) {
      return false;
    }
  }

  _HomeScope _resolveScope() {
    final focus = FocusManager.instance.primaryFocus;
    final ctx = focus?.context;
    final context = (ctx is Element && ctx.debugIsActive) ? ctx : null;
    try {
      if (context != null &&
          context.findAncestorWidgetOfExactType<InlineReplyComposer>() != null) {
        return _HomeScope.editor;
      }
    } catch (_) {}
    if (_threadDetailFocusNode.hasFocus) {
      return _HomeScope.detail;
    }
    if (_threadListFocusNode.hasFocus) {
      return _HomeScope.list;
    }
    return _HomeScope.list;
  }

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _runRefresh(EmailProvider provider) async {
    if (_isRefreshing) {
      return;
    }
    setState(() => _isRefreshing = true);
    try {
      await provider.refresh();
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  Map<LogicalKeySet, Intent> _shortcutMap(
    TidingsSettings settings, {
    required bool allowGlobal,
  }) {
    final shortcuts = <LogicalKeySet, Intent>{};

    void addShortcut(ShortcutAction action, KeyboardShortcut shortcut) {
      if (!allowGlobal &&
          action != ShortcutAction.focusSearch &&
          action != ShortcutAction.sendMessage &&
          action != ShortcutAction.openSettings) {
        return;
      }
      shortcuts[shortcut.toKeySet()] = _ShortcutIntent(action);
    }

    for (final definition in shortcutDefinitions) {
      addShortcut(definition.action, settings.shortcutFor(definition.action));
      final secondary = settings.secondaryShortcutFor(definition.action);
      if (secondary != null) {
        addShortcut(definition.action, secondary);
      }
    }
    shortcuts[_escapeKey] = const _BlurIntent();

    return shortcuts;
  }

  void _scheduleMenuSelectionUpdate(EmailProvider provider) {
    final thread = _currentThread(provider);
    final latest = thread == null
        ? null
        : provider.latestMessageForThread(thread.id);
    final hasSelection = thread != null;
    final isUnread =
        thread != null && (thread.unread || (latest?.isUnread ?? false));
    if (widget.appState.menuHasThreadSelection == hasSelection &&
        widget.appState.menuThreadUnread == isUnread) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      widget.appState.updateMenuSelection(
        hasSelection: hasSelection,
        isUnread: isUnread,
      );
    });
  }

  EmailThread? _currentThread(EmailProvider provider) {
    final threads = provider.threads;
    if (threads.isEmpty) {
      return null;
    }
    final index = selectedIndex(_selectedThreadIndex, threads.length);
    return threads[index];
  }

  void _navigateSelection(EmailProvider provider, int delta) {
    final threads = provider.threads;
    if (threads.isEmpty) {
      return;
    }
    setState(() {
      _selectedThreadIndex = (_selectedThreadIndex + delta).clamp(
        0,
        threads.length - 1,
      );
    });
    _syncAccentWithSelection(provider);
    _threadListFocusNode.requestFocus();
  }

  // Call after a thread has been removed from the list (archive / move).
  // Keeping the same index value advances to what was the next thread;
  // if it was the last thread the selectedIndex() helper clamps it down.
  void _advanceAfterRemoval(EmailProvider provider) {
    setState(() {
      // Index stays the same — the list is now one shorter so this naturally
      // points at the successor.  selectedIndex() will clamp if needed.
    });
    _syncAccentWithSelection(provider);
    _threadListFocusNode.requestFocus();
  }

  int _selectedMessageIndexForThread(EmailThread thread, int messageCount) {
    if (messageCount <= 0) {
      return 0;
    }
    final stored = _messageSelectionByThread[thread.id];
    if (stored == null) {
      return messageCount - 1;
    }
    return stored.clamp(0, messageCount - 1);
  }

  void _setMessageSelection(String threadId, int index) {
    setState(() {
      _messageSelectionByThread[threadId] = index;
    });
    _threadDetailFocusNode.requestFocus();
  }

  /// Common handler for tapping / keyboard-selecting a thread in either layout.
  void _handleThreadSelected(EmailProvider listProvider, int index) {
    final threads = listProvider.threads;
    final safeIndex = threads.isEmpty ? 0 : index.clamp(0, threads.length - 1);
    final thread = threads.isEmpty ? null : threads[safeIndex];
    setState(() {
      _selectedThreadIndex = index;
      _threadPanelOpen = true;
      _showSettings = false;
      if (thread != null) {
        final messages = listProvider.messagesForThread(thread.id);
        if (messages.isNotEmpty) {
          _messageSelectionByThread[thread.id] = messages.length - 1;
        }
      }
    });
    _syncAccentWithSelection(listProvider);
    _threadListFocusNode.requestFocus();
  }

  void _navigateMessageSelection(EmailProvider provider, int delta) {
    final thread = _currentThread(provider);
    if (thread == null) {
      return;
    }
    final messages = provider.messagesForThread(thread.id);
    if (messages.isEmpty) {
      return;
    }
    final current = _selectedMessageIndexForThread(thread, messages.length);
    final next = (current + delta).clamp(0, messages.length - 1);
    setState(() {
      _messageSelectionByThread[thread.id] = next;
      _threadPanelOpen = true;
      _showSettings = false;
    });
    _threadDetailFocusNode.requestFocus();
  }

  void _navigateByScope(EmailProvider provider, int delta) {
    final scope = _resolveScope();
    if (scope == _HomeScope.detail) {
      _navigateMessageSelection(provider, delta);
      return;
    }
    if (scope == _HomeScope.list) {
      _navigateSelection(provider, delta);
    }
  }

  Future<void> _toggleReadForSelected(EmailProvider provider) async {
    final thread = _currentThread(provider);
    if (thread == null) {
      _toast('No thread selected.');
      return;
    }
    final latest = provider.latestMessageForThread(thread.id);
    final isUnread = thread.unread || (latest?.isUnread ?? false);
    final error = await provider.setThreadUnread(thread, !isUnread);
    if (error != null) {
      _toast(error);
      return;
    }
    _toast(isUnread ? 'Marked as read.' : 'Marked as unread.');
    _scheduleMenuSelectionUpdate(provider);
  }

  void _focusThreadDetail() {
    FocusManager.instance.primaryFocus?.unfocus();
    Future.delayed(const Duration(milliseconds: 240), () {
      if (mounted) {
        _threadDetailFocusNode.requestFocus();
      }
    });
  }

  Future<void> _openSelectedThread(
    EmailProvider provider,
    EmailAccount account,
  ) async {
    final thread = _currentThread(provider);
    if (thread == null) {
      _toast('No thread selected.');
      return;
    }
    final currentUserEmail = _currentUserEmailForThread(thread, account);
    if (context.isCompact) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ThreadScreen(
            accent: widget.accent,
            thread: thread,
            provider: provider,
            currentUserEmail: currentUserEmail,
          ),
        ),
      );
      if (mounted) {
        _threadListFocusNode.requestFocus();
      }
    } else {
      setState(() {
        _threadPanelOpen = true;
        _showSettings = false;
      });
      _focusThreadDetail();
    }
  }

  Future<void> _triggerReply(
    EmailProvider provider,
    EmailAccount account,
    ReplyMode mode,
  ) async {
    final thread = _currentThread(provider);
    if (thread == null) {
      _toast('No thread selected.');
      return;
    }
    final isWide = MediaQuery.sizeOf(context).width >= kCompactBreakpoint;
    final detailOpen = isWide && _threadPanelOpen && !_showSettings;
    if (!detailOpen) {
      await _openReplyFromList(provider, account, thread, mode);
      return;
    }
    setState(() {
      _threadPanelOpen = true;
      _showSettings = false;
    });
    _inlineReplyController.setModeForThread(thread.id, mode);
    _inlineReplyController.focusEditorForThread(thread.id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _inlineReplyController.setModeForThread(thread.id, mode);
      _inlineReplyController.focusEditorForThread(thread.id);
    });
  }

  Future<void> _openReplyFromList(
    EmailProvider provider,
    EmailAccount account,
    EmailThread thread,
    ReplyMode mode,
  ) async {
    final currentUserEmail = _currentUserEmailForThread(thread, account);
    final latest = provider.latestMessageForThread(thread.id);
    final subject = mode == ReplyMode.forward
        ? forwardSubject(thread.subject)
        : replySubject(thread.subject);
    String to;
    switch (mode) {
      case ReplyMode.replyAll:
        to = replyRecipients(thread.participants, currentUserEmail);
        break;
      case ReplyMode.forward:
        to = '';
        break;
      case ReplyMode.reply:
        // Prefer Reply-To header over From — RFC 5322 §3.6.2.
        final replyAddress = effectiveReplyTo(
          replyToAddresses: latest?.replyTo ?? const [],
          from: latest?.from,
          participants: thread.participants,
          currentUserEmail: currentUserEmail,
        );
        to = replyAddress?.email ?? '';
        break;
    }
    final quoted = buildQuotedContent(
      latest,
      isForward: mode == ReplyMode.forward,
      settings: context.tidingsSettings,
    );
    await showComposeSheet(
      context,
      provider: provider,
      accent: widget.accent,
      thread: thread,
      currentUserEmail: currentUserEmail,
      initialTo: to,
      initialSubject: subject,
      quotedContent: quoted,
    );
  }

  Future<void> _archiveSelectedThread(EmailProvider provider) async {
    final thread = _currentThread(provider);
    if (thread == null) {
      _toast('No thread selected.');
      return;
    }
    final error = await provider.archiveThread(thread);
    if (error != null) {
      _toast(error);
      return;
    }
    _advanceAfterRemoval(provider);
    _toast('Archived ${subjectLabel(thread.subject)}');
  }

  Future<void> _moveSelectedThreadToFolder(
    EmailProvider provider,
    EmailAccount account,
  ) async {
    final thread = _currentThread(provider);
    if (thread == null) {
      _toast('No thread selected.');
      return;
    }
    final settings = context.tidingsSettings;
    // Resolve the real (single-account) provider for folder sections.
    final realProvider = provider is UnifiedEmailProvider
        ? provider.providerForThread(thread.id) ?? provider
        : provider;
    final entries = buildMoveToFolderEntries(
      realProvider.folderSections,
      currentFolderPath: provider.selectedFolderPath,
    );
    if (!mounted) {
      return;
    }
    final messages = provider.messagesForThread(thread.id);
    final result = await showMoveToFolderDialog(
      context,
      accent: widget.accent,
      entries: entries,
      messageCount: messages.length,
      defaultMoveEntireThread: settings.moveEntireThreadByDefault,
      // Folder-level action always moves the whole thread — no toggle needed.
      showThreadToggle: false,
    );
    if (result == null || !mounted) {
      return;
    }
    final error = await provider.moveToFolder(thread, result.folderPath);
    if (!mounted) {
      return;
    }
    if (error != null) {
      _toast('Move failed: $error');
      return;
    }
    _advanceAfterRemoval(provider);
    _toast('Moved ${subjectLabel(thread.subject)}');
  }

  Future<void> _showCommandPalette(
    EmailProvider provider,
    EmailAccount account,
  ) async {
    final settings = context.tidingsSettings;
    final items = [
      CommandPaletteItem(
        id: 'compose',
        title: 'Compose',
        subtitle: 'Start a new message',
        shortcutLabel: settings.shortcutLabel(ShortcutAction.compose),
        onSelected: () =>
            _handleShortcut(ShortcutAction.compose, provider, account),
      ),
      CommandPaletteItem(
        id: 'reply',
        title: 'Reply',
        subtitle: 'Reply to the selected thread',
        shortcutLabel: settings.shortcutLabel(ShortcutAction.reply),
        onSelected: () =>
            _handleShortcut(ShortcutAction.reply, provider, account),
      ),
      CommandPaletteItem(
        id: 'reply-all',
        title: 'Reply all',
        subtitle: 'Reply to everyone in the thread',
        shortcutLabel: settings.shortcutLabel(ShortcutAction.replyAll),
        onSelected: () =>
            _handleShortcut(ShortcutAction.replyAll, provider, account),
      ),
      CommandPaletteItem(
        id: 'forward',
        title: 'Forward',
        subtitle: 'Forward the selected thread',
        shortcutLabel: settings.shortcutLabel(ShortcutAction.forward),
        onSelected: () =>
            _handleShortcut(ShortcutAction.forward, provider, account),
      ),
      CommandPaletteItem(
        id: 'archive',
        title: 'Archive',
        subtitle: 'Move to Archive',
        shortcutLabel: settings.shortcutLabel(ShortcutAction.archive),
        onSelected: () =>
            _handleShortcut(ShortcutAction.archive, provider, account),
      ),
      CommandPaletteItem(
        id: 'move-to-folder',
        title: 'Move to folder',
        subtitle: 'Move the selected thread to a folder',
        shortcutLabel: settings.shortcutLabel(ShortcutAction.moveToFolder),
        onSelected: () =>
            _handleShortcut(ShortcutAction.moveToFolder, provider, account),
      ),
      CommandPaletteItem(
        id: 'toggle-read',
        title: 'Mark read/unread',
        subtitle: 'Toggle the selected thread read state',
        shortcutLabel: settings.shortcutLabel(ShortcutAction.toggleRead),
        onSelected: () =>
            _handleShortcut(ShortcutAction.toggleRead, provider, account),
      ),
      CommandPaletteItem(
        id: 'go-to',
        title: 'Go to folder',
        subtitle: 'Jump to any folder',
        shortcutLabel: settings.shortcutLabel(ShortcutAction.goTo),
        onSelected: () =>
            _handleShortcut(ShortcutAction.goTo, provider, account),
      ),
      CommandPaletteItem(
        id: 'go-to-account',
        title: 'Go to folder (current account)',
        subtitle: 'Jump within this account',
        shortcutLabel: settings.shortcutLabel(ShortcutAction.goToAccount),
        onSelected: () =>
            _handleShortcut(ShortcutAction.goToAccount, provider, account),
      ),
      CommandPaletteItem(
        id: 'search',
        title: 'Focus search',
        subtitle: 'Jump to the search field',
        shortcutLabel: settings.shortcutLabel(ShortcutAction.focusSearch),
        onSelected: () =>
            _handleShortcut(ShortcutAction.focusSearch, provider, account),
      ),
      CommandPaletteItem(
        id: 'shortcuts',
        title: 'Show shortcuts',
        subtitle: 'View all keyboard shortcuts',
        shortcutLabel: settings.shortcutLabel(ShortcutAction.showShortcuts),
        onSelected: () =>
            _handleShortcut(ShortcutAction.showShortcuts, provider, account),
      ),
    ];
    await showCommandPalette(context, accent: widget.accent, items: items);
  }

  Future<void> _showGoToDialog({required bool currentAccountOnly}) async {
    final entries = await _buildGoToEntries(
      currentAccountOnly: currentAccountOnly,
    );
    if (!mounted) {
      return;
    }
    await showGoToDialog(
      context,
      accent: widget.accent,
      entries: entries,
      title: currentAccountOnly ? 'Go to (this account)' : 'Go to',
    );
  }

  Future<List<GoToEntry>> _buildGoToEntries({
    required bool currentAccountOnly,
  }) async {
    final entries = <GoToEntry>[];
    final accounts = widget.appState.accounts;
    final currentAccountId = widget.appState.selectedAccount?.id;
    // Only treat entries as priority when in single-account view (not unified).
    final inSingleAccountView = currentAccountId != null &&
        widget.appState.selectedAccount != null &&
        widget.appState.currentProvider is! UnifiedEmailProvider;

    // Add "Unified Inbox" entry when showing all accounts and there are
    // multiple accounts to merge.
    if (!currentAccountOnly && accounts.length > 1) {
      entries.add(
        GoToEntry(
          title: 'Unified Inbox',
          subtitle: '${accounts.length} accounts',
          accentColor: widget.accent,
          isPriority: _isUnifiedInbox, // sort to top when already in unified
          onSelected: _enableUnifiedInbox,
        ),
      );
    }

    for (var index = 0; index < accounts.length; index++) {
      final account = accounts[index];
      if (currentAccountOnly && account.id != currentAccountId) {
        continue;
      }
      final provider = widget.appState.providerForAccount(account.id);
      if (provider == null) {
        continue;
      }
      if (provider.status == ProviderStatus.idle) {
        await provider.initialize();
      }
      final accountAccent = account.accentColorValue != null
          ? Color(account.accentColorValue!)
          : accentFromAccount(account.id);
      final isCurrentAccount = account.id == currentAccountId;
      for (final section in provider.folderSections) {
        for (final item in section.items) {
          entries.add(
            GoToEntry(
              title: item.name,
              subtitle: '${account.displayName} · ${account.email}',
              accentColor: accountAccent,
              isPriority: inSingleAccountView && isCurrentAccount,
              onSelected: () async {
                await widget.appState.selectAccount(index);
                final nextProvider = widget.appState.currentProvider;
                if (nextProvider == null) {
                  return;
                }
                _handleFolderSelected(nextProvider, item.index);
              },
            ),
          );
        }
      }
    }
    return entries;
  }

  Future<void> _handleShortcut(
    ShortcutAction action,
    EmailProvider provider,
    EmailAccount account,
  ) async {
    switch (action) {
      case ShortcutAction.compose:
        final composeProvider = widget.appState.currentProvider ?? provider;
        await showComposeSheet(
          context,
          provider: composeProvider,
          accent: widget.accent,
          currentUserEmail: account.email,
        );
        break;
      case ShortcutAction.reply:
        await _triggerReply(provider, account, ReplyMode.reply);
        break;
      case ShortcutAction.replyAll:
        await _triggerReply(provider, account, ReplyMode.replyAll);
        break;
      case ShortcutAction.forward:
        await _triggerReply(provider, account, ReplyMode.forward);
        break;
      case ShortcutAction.archive:
        await _archiveSelectedThread(provider);
        break;
      case ShortcutAction.moveToFolder:
        await _moveSelectedThreadToFolder(provider, account);
        break;
      case ShortcutAction.toggleRead:
        await _toggleReadForSelected(provider);
        break;
      case ShortcutAction.commandPalette:
        await _showCommandPalette(provider, account);
        break;
      case ShortcutAction.goTo:
        await _showGoToDialog(currentAccountOnly: false);
        break;
      case ShortcutAction.goToAccount:
        await _showGoToDialog(currentAccountOnly: true);
        break;
      case ShortcutAction.focusSearch:
        await _handleSearchTap(provider);
        break;
      case ShortcutAction.openSettings:
        setState(() {
          _showSettings = true;
          _navIndex = 3;
        });
        break;
      case ShortcutAction.sendMessage:
        await _inlineReplyController.send();
        break;
      case ShortcutAction.toggleSidebar:
        if (MediaQuery.sizeOf(context).width < kCompactBreakpoint) {
          return;
        }
        setState(() {
          _sidebarCollapsed = !_sidebarCollapsed;
        });
        context.tidingsSettings.setSidebarCollapsed(_sidebarCollapsed);
        break;
      case ShortcutAction.openThread:
        await _openSelectedThread(provider, account);
        break;
      case ShortcutAction.navigateNext:
        _navigateByScope(provider, 1);
        break;
      case ShortcutAction.navigatePrev:
        _navigateByScope(provider, -1);
        break;
      case ShortcutAction.showShortcuts:
        await showShortcutsSheet(context);
        break;
    }
  }

  void _handleMenuAction(ShortcutAction action) {
    final account = widget.appState.selectedAccount;
    final provider =
        _isUnifiedInbox ? _unifiedProvider : widget.appState.currentProvider;
    if (account == null || provider == null) {
      return;
    }
    _handleShortcut(action, provider, account);
  }

  @override
  Widget build(BuildContext context) {
    final account = widget.appState.selectedAccount;
    final provider = widget.appState.currentProvider;
    if (account == null || provider == null) {
      return const SizedBox.shrink();
    }
    final listProvider = _isUnifiedInbox ? _unifiedProvider : provider;
    _scheduleMenuSelectionUpdate(listProvider);
    return AnimatedBuilder(
      animation: FocusManager.instance,
      builder: (context, _) {
        final settings = context.tidingsSettings;
        final isRecordingShortcut = _isShortcutRecorderFocused();
        final allowGlobal = !_isTextInputFocused() && !_inlineReplyFocused;
        final scope = _resolveScope();
        final threadFocused = scope != _HomeScope.list;
        final listCurrentUserEmail = _isUnifiedInbox ? '' : account.email;
        return Shortcuts(
          shortcuts: isRecordingShortcut
              ? const <LogicalKeySet, Intent>{}
              : _shortcutMap(settings, allowGlobal: allowGlobal),
          child: Actions(
            actions: {
              _ShortcutIntent: CallbackAction<_ShortcutIntent>(
                onInvoke: (intent) {
                  final currentAccount = widget.appState.selectedAccount;
                  if (currentAccount == null) {
                    return null;
                  }
                  _handleShortcut(intent.action, listProvider, currentAccount);
                  return null;
                },
              ),
              _BlurIntent: CallbackAction<_BlurIntent>(
                onInvoke: (intent) {
                  FocusManager.instance.primaryFocus?.unfocus();
                  _rootFocusNode.requestFocus();
                  return null;
                },
              ),
            },
            child: Focus(
              focusNode: _rootFocusNode,
              autofocus: true,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= kCompactBreakpoint;
                  final showSettings = _showSettings;
                  final augmentedSections =
                      _augmentedFolderSections(listProvider);
                  final effectiveFolderIndex =
                      _folderIndexForPath(
                        augmentedSections,
                        listProvider.selectedFolderPath,
                      ) ??
                      _selectedFolderIndex;
                  final threads = listProvider.threads;
                  final safeThreadIndex = threads.isEmpty
                      ? 0
                      : selectedIndex(_selectedThreadIndex, threads.length);
                  final selectedThread = threads.isEmpty
                      ? null
                      : threads[safeThreadIndex];
                  final selectedMessageIndex = selectedThread == null
                      ? 0
                      : _selectedMessageIndexForThread(
                          selectedThread,
                          listProvider
                              .messagesForThread(selectedThread.id)
                              .length,
                        );
                  final detailCurrentUserEmail = _currentUserEmailForThread(
                    selectedThread,
                    account,
                  );

                  return Scaffold(
                    extendBody: true,
                    floatingActionButtonLocation:
                        FloatingActionButtonLocation.endFloat,
                    floatingActionButton: isWide
                        ? null
                        : GlassPanel(
                            borderRadius: BorderRadius.circular(
                              context.radius(18),
                            ),
                            padding: EdgeInsets.all(context.space(6)),
                            variant: GlassVariant.pill,
                            accent: widget.accent,
                            selected: true,
                            child: IconButton(
                              onPressed: () => showComposeSheet(
                                context,
                                provider: provider,
                                accent: widget.accent,
                                currentUserEmail: account.email,
                              ),
                              icon: const Icon(Icons.edit_rounded),
                              tooltip:
                                  'Compose (${context.tidingsSettings.shortcutLabel(ShortcutAction.compose, includeSecondary: false)})',
                            ),
                          ),
                    bottomNavigationBar: null,
                    body: TidingsBackground(
                      child: SafeArea(
                        bottom: false,
                        child: isWide
                            ? WideLayout(
                                appState: widget.appState,
                                account: account,
                                accent: widget.accent,
                                isUnified: _isUnifiedInbox,
                                provider: listProvider,
                                onSearchTap: () =>
                                    _handleSearchTap(listProvider),
                                activeSearchQuery: _activeSearch?.rawQuery,
                                onSearchClear: () =>
                                    _clearSearch(listProvider),
                                folderSectionsOverride: augmentedSections,
                                selectedThreadIndex: _selectedThreadIndex,
                                onThreadSelected: (index) =>
                                    _handleThreadSelected(listProvider, index),
                                selectedFolderIndex: effectiveFolderIndex,
                                onFolderSelected: (index) =>
                                    _handleFolderSelected(listProvider, index),
                                sidebarCollapsed: _sidebarCollapsed,
                                onSidebarToggle: () {
                                  final next = !_sidebarCollapsed;
                                  setState(() {
                                    _sidebarCollapsed = next;
                                  });
                                  settings.setSidebarCollapsed(next);
                                },
                                onAccountTap: () => showAccountPickerSheet(
                                  context,
                                  appState: widget.appState,
                                  accent: widget.accent,
                                  showMockOption: true,
                                  showUnifiedOption: true,
                                  onSelectUnified: _enableUnifiedInbox,
                                  onSelectAccount: _disableUnifiedInbox,
                                ),
                                onOutboxTap: () => _openOutbox(listProvider),
                                onRefreshTap: () => _runRefresh(listProvider),
                                isRefreshing: _isRefreshing,
                                outboxCount: listProvider.outboxCount,
                                outboxSelected:
                                    listProvider.selectedFolderPath ==
                                    kOutboxFolderPath,
                                navIndex: _navIndex,
                                onNavSelected: (index) => setState(() {
                                  _navIndex = index;
                                  _showSettings = false;
                                }),
                                onSettingsTap: () =>
                                    setState(() => _showSettings = true),
                                onSettingsClose: () =>
                                    setState(() => _showSettings = false),
                                showSettings: showSettings,
                                threadFocused: threadFocused,
                                threadListFocusNode: _threadListFocusNode,
                                threadDetailFocusNode: _threadDetailFocusNode,
                                threadDetailScrollController:
                                    _threadDetailScrollController,
                                onThreadDetailKeyEvent:
                                    _handleThreadDetailKeyEvent,
                                threadPanelFraction: _threadPanelFraction,
                                threadPanelOpen: _threadPanelOpen,
                                onThreadPanelResize: (fraction) {
                                  setState(
                                    () => _threadPanelFraction = fraction,
                                  );
                                },
                                onThreadPanelResizeEnd: () {
                                  settings.setThreadPanelFraction(
                                    _threadPanelFraction,
                                  );
                                },
                                onThreadPanelOpen: () =>
                                    setState(() => _threadPanelOpen = true),
                                onThreadPanelClose: () =>
                                    setState(() => _threadPanelOpen = false),
                                onCompose: () => showComposeSheet(
                                  context,
                                  provider: provider,
                                  accent: widget.accent,
                                  currentUserEmail: account.email,
                                ),
                                searchFocusNode: _searchFocusNode,
                                replyController: _inlineReplyController,
                                onReplyFocusChange:
                                    _handleInlineReplyFocusChange,
                                listCurrentUserEmail: listCurrentUserEmail,
                                detailCurrentUserEmail: detailCurrentUserEmail,
                                selectedMessageIndex: selectedMessageIndex,
                                onMessageSelected: (index) {
                                  if (selectedThread == null) {
                                    return;
                                  }
                                  _setMessageSelection(
                                    selectedThread.id,
                                    index,
                                  );
                                },
                                savedSearches: _savedSearches,
                              )
                            : showSettings
                            ? SettingsScreen(
                                accent: widget.accent,
                                appState: widget.appState,
                                onClose: () => setState(() {
                                  _showSettings = false;
                                  _navIndex = 0;
                                }),
                              )
                            : CompactLayout(
                                account: account,
                                accent: widget.accent,
                                isUnified: _isUnifiedInbox,
                                provider: listProvider,
                                onSearchTap: () =>
                                    _handleSearchTap(listProvider),
                                activeSearchQuery: _activeSearch?.rawQuery,
                                onSearchClear: () =>
                                    _clearSearch(listProvider),
                                folderSectionsOverride: augmentedSections,
                                selectedThreadIndex: _selectedThreadIndex,
                                onThreadSelected: (index) =>
                                    _handleThreadSelected(listProvider, index),
                                selectedFolderIndex: effectiveFolderIndex,
                                onFolderSelected: (index) {
                                  _handleFolderSelected(listProvider, index);
                                  if (_compactRailOpen) {
                                    setState(() => _compactRailOpen = false);
                                  }
                                },
                                onAccountTap: () => showAccountPickerSheet(
                                  context,
                                  appState: widget.appState,
                                  accent: widget.accent,
                                  showMockOption: true,
                                  showUnifiedOption: true,
                                  onSelectUnified: _enableUnifiedInbox,
                                  onSelectAccount: _disableUnifiedInbox,
                                ),
                                onCompose: () => showComposeSheet(
                                  context,
                                  provider: provider,
                                  accent: widget.accent,
                                  currentUserEmail: account.email,
                                ),
                                onOutboxTap: () => _openOutbox(listProvider),
                                onRefreshTap: () => _runRefresh(listProvider),
                                onSettingsTap: () =>
                                    setState(() => _showSettings = true),
                                outboxCount: listProvider.outboxCount,
                                outboxSelected:
                                    listProvider.selectedFolderPath ==
                                    kOutboxFolderPath,
                                isRefreshing: _isRefreshing,
                                railOpen: _compactRailOpen,
                                railExpanded: _compactRailExpanded,
                                onRailToggle: (open) {
                                  setState(() {
                                    _compactRailOpen = open;
                                    if (!open) {
                                      _compactRailExpanded = false;
                                    }
                                  });
                                },
                                onRailExpand: () {
                                  setState(() {
                                    _compactRailOpen = true;
                                    _compactRailExpanded = true;
                                  });
                                },
                                onRailCollapse: () {
                                  setState(() {
                                    _compactRailOpen = true;
                                    _compactRailExpanded = false;
                                  });
                                },
                                searchFocusNode: _searchFocusNode,
                                threadListFocusNode: _threadListFocusNode,
                                listCurrentUserEmail: listCurrentUserEmail,
                                currentUserEmailForThread: (thread) =>
                                    _currentUserEmailForThread(thread, account),
                                accountCount: widget.appState.accounts.length,
                                savedSearches: _savedSearches,
                              ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
