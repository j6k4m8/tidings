import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../models/account_models.dart';
import '../models/email_models.dart';
import '../models/folder_models.dart';
import '../providers/email_provider.dart';
import '../providers/unified_email_provider.dart';
import '../state/app_state.dart';
import '../state/send_queue.dart';
import '../state/tidings_settings.dart';
import '../state/shortcut_definitions.dart';
import '../state/keyboard_shortcut.dart';
import '../theme/glass.dart';
import '../widgets/settings/shortcut_recorder.dart';
import '../widgets/tidings_background.dart';
import 'compose/compose_sheet.dart';
import 'compose/inline_reply_composer.dart';
import 'home/home_utils.dart';
import 'home/home_layouts.dart';
import 'home/thread_detail.dart';
import 'keyboard/command_palette.dart';
import 'keyboard/go_to_dialog.dart';
import 'keyboard/shortcuts_sheet.dart';
import 'onboarding_screen.dart';
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
  bool _isRefreshing = false;
  bool _compactRailOpen = false;
  bool _compactRailExpanded = false;

  @override
  void initState() {
    super.initState();
    _lastAccountId = widget.appState.selectedAccount?.id;
    widget.appState.addListener(_handleAppStateChange);
    FocusManager.instance.addListener(_handleGlobalFocusChange);
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
    FocusManager.instance.removeListener(_handleGlobalFocusChange);
    _settings?.removeListener(_handleSettingsChange);
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
    final path = _folderPathForIndex(provider.folderSections, index);
    if (_isUnifiedInbox &&
        path != kOutboxFolderPath &&
        path != 'INBOX') {
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

  void _openOutbox(EmailProvider provider) {
    final index =
        _folderIndexForPath(provider.folderSections, kOutboxFolderPath);
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

  String? _folderPathForIndex(List<FolderSection> sections, int index) {
    for (final section in sections) {
      for (final item in section.items) {
        if (item.index == index) {
          return item.path;
        }
      }
    }
    return null;
  }

  String _currentUserEmailForThread(
    EmailThread? thread,
    EmailAccount fallback,
  ) {
    if (!_isUnifiedInbox || thread == null) {
      return fallback.email;
    }
    return _unifiedProvider.accountEmailForThread(thread.id) ?? fallback.email;
  }

  int? _folderIndexForPath(List<FolderSection> sections, String path) {
    for (final section in sections) {
      for (final item in section.items) {
        if (item.path == path) {
          return item.index;
        }
      }
    }
    return null;
  }

  bool _isTextInputFocused() {
    final focus = FocusManager.instance.primaryFocus;
    if (focus == null) {
      return false;
    }
    final context = focus.context;
    if (context == null) {
      return false;
    }
    final widget = context.widget;
    if (widget is EditableText || widget is QuillEditor) {
      return true;
    }
    return context.findAncestorWidgetOfExactType<EditableText>() != null ||
        context.findAncestorWidgetOfExactType<QuillEditor>() != null;
  }

  bool _isShortcutRecorderFocused() {
    final focus = FocusManager.instance.primaryFocus;
    if (focus == null) {
      return false;
    }
    final context = focus.context;
    if (context == null) {
      return false;
    }
    return context.findAncestorWidgetOfExactType<ShortcutRecorder>() != null;
  }

  _HomeScope _resolveScope() {
    final focus = FocusManager.instance.primaryFocus;
    final context = focus?.context;
    if (context != null &&
        context.findAncestorWidgetOfExactType<InlineReplyComposer>() != null) {
      return _HomeScope.editor;
    }
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
    final isCompact = MediaQuery.of(context).size.width < 720;
    if (isCompact) {
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _threadDetailFocusNode.requestFocus();
        }
      });
    }
  }

  void _triggerReply(
    EmailProvider provider,
    EmailAccount account,
    ReplyMode mode,
  ) {
    final thread = _currentThread(provider);
    if (thread == null) {
      _toast('No thread selected.');
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
    _toast('Archived.');
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
      for (final section in provider.folderSections) {
        for (final item in section.items) {
          entries.add(
            GoToEntry(
              title: item.name,
              subtitle: '${account.displayName} · ${account.email}',
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
        _triggerReply(provider, account, ReplyMode.reply);
        break;
      case ShortcutAction.replyAll:
        _triggerReply(provider, account, ReplyMode.replyAll);
        break;
      case ShortcutAction.forward:
        _triggerReply(provider, account, ReplyMode.forward);
        break;
      case ShortcutAction.archive:
        await _archiveSelectedThread(provider);
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
        _searchFocusNode.requestFocus();
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
        if (MediaQuery.of(context).size.width < 1024) {
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

  @override
  Widget build(BuildContext context) {
    final account = widget.appState.selectedAccount;
    final provider = widget.appState.currentProvider;
    if (account == null || provider == null) {
      return const SizedBox.shrink();
    }
    final listProvider = _isUnifiedInbox ? _unifiedProvider : provider;
    return AnimatedBuilder(
      animation: FocusManager.instance,
      builder: (context, _) {
        final settings = context.tidingsSettings;
        final isRecordingShortcut = _isShortcutRecorderFocused();
        final allowGlobal = !_isTextInputFocused();
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
                  final isWide = constraints.maxWidth >= 1024;
                  final showSettings = _showSettings;
                  final effectiveFolderIndex =
                      _folderIndexForPath(
                        listProvider.folderSections,
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
                      accent: widget.accent,
                      child: SafeArea(
                        bottom: false,
                        child: isWide
                            ? WideLayout(
                                appState: widget.appState,
                                account: account,
                                accent: widget.accent,
                                provider: listProvider,
                                selectedThreadIndex: _selectedThreadIndex,
                                onThreadSelected: (index) {
                                  final threads = listProvider.threads;
                                  final safeIndex = threads.isEmpty
                                      ? 0
                                      : index.clamp(0, threads.length - 1);
                                  final thread = threads.isEmpty
                                      ? null
                                      : threads[safeIndex];
                                  setState(() {
                                    _selectedThreadIndex = index;
                                    _threadPanelOpen = true;
                                    _showSettings = false;
                                    if (thread != null) {
                                      final messages = listProvider
                                          .messagesForThread(thread.id);
                                      if (messages.isNotEmpty) {
                                        _messageSelectionByThread[thread.id] =
                                            messages.length - 1;
                                      }
                                    }
                                  });
                                  _syncAccentWithSelection(listProvider);
                                  _threadListFocusNode.requestFocus();
                                },
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
                                provider: listProvider,
                                selectedThreadIndex: _selectedThreadIndex,
                                onThreadSelected: (index) {
                                  final threads = listProvider.threads;
                                  final safeIndex = threads.isEmpty
                                      ? 0
                                      : index.clamp(0, threads.length - 1);
                                  final thread = threads.isEmpty
                                      ? null
                                      : threads[safeIndex];
                                  setState(() {
                                    _selectedThreadIndex = index;
                                    _threadPanelOpen = true;
                                    _showSettings = false;
                                    if (thread != null) {
                                      final messages = listProvider
                                          .messagesForThread(thread.id);
                                      if (messages.isNotEmpty) {
                                        _messageSelectionByThread[thread.id] =
                                            messages.length - 1;
                                      }
                                    }
                                  });
                                  _syncAccentWithSelection(listProvider);
                                  _threadListFocusNode.requestFocus();
                                },
                                selectedFolderIndex: effectiveFolderIndex,
                                onFolderSelected: (index) {
                                  _handleFolderSelected(listProvider, index);
                                  if (_compactRailOpen) {
                                    setState(
                                      () => _compactRailOpen = false,
                                    );
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
