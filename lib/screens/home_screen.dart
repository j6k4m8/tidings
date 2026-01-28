import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../models/account_models.dart';
import '../models/email_models.dart';
import '../models/folder_models.dart';
import '../providers/email_provider.dart';
import '../providers/unified_email_provider.dart';
import '../state/app_state.dart';
import '../state/tidings_settings.dart';
import '../state/shortcut_definitions.dart';
import '../state/keyboard_shortcut.dart';
import '../theme/color_tokens.dart';
import '../theme/glass.dart';
import '../theme/account_accent.dart';
import '../theme/theme_palette.dart';
import '../widgets/accent_switch.dart';
import '../widgets/account/account_avatar.dart';
import '../widgets/accent/accent_presets.dart';
import '../widgets/accent/accent_swatch.dart';
import '../widgets/glass/glass_action_button.dart';
import '../widgets/glass/glass_bottom_nav.dart';
import '../widgets/settings/corner_radius_option.dart';
import '../widgets/settings/settings_rows.dart';
import '../widgets/settings/settings_tabs.dart';
import '../widgets/settings/shortcut_recorder.dart';
import '../widgets/animations/page_reveal.dart';
import '../widgets/tidings_background.dart';
import 'compose/compose_sheet.dart';
import 'compose/inline_reply_composer.dart';
import 'home/thread_detail.dart';
import 'home/thread_list.dart';
import 'keyboard/command_palette.dart';
import 'keyboard/go_to_dialog.dart';
import 'keyboard/shortcuts_sheet.dart';
import 'onboarding_screen.dart';

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
    final index = _selectedIndex(_selectedThreadIndex, threads.length);
    final thread = threads[index];
    final account = _unifiedProvider.accountForThread(thread.id);
    widget.appState.setAccentAccountId(account?.id);
  }

  void _handleFolderSelected(EmailProvider provider, int index) {
    if (_isUnifiedInbox) {
      return;
    }
    final path = _folderPathForIndex(provider.folderSections, index);
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
    final index = _selectedIndex(_selectedThreadIndex, threads.length);
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
                      : _selectedIndex(_selectedThreadIndex, threads.length);
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
                        : GlassActionButton(
                            accent: widget.accent,
                            label: 'Compose',
                            icon: Icons.edit_rounded,
                            onTap: () => showComposeSheet(
                              context,
                              provider: provider,
                              accent: widget.accent,
                              currentUserEmail: account.email,
                            ),
                            tooltip:
                                'Compose (${context.tidingsSettings.shortcutLabel(ShortcutAction.compose, includeSecondary: false)})',
                          ),
                    bottomNavigationBar: isWide
                        ? null
                        : GlassBottomNav(
                            accent: widget.accent,
                            currentIndex: _navIndex,
                            onTap: (index) => setState(() {
                              _navIndex = index;
                              _showSettings = index == 3;
                            }),
                          ),
                    body: TidingsBackground(
                      accent: widget.accent,
                      child: SafeArea(
                        bottom: false,
                        child: isWide
                            ? _WideLayout(
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
                            : _CompactLayout(
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
                                onAccountTap: () => showAccountPickerSheet(
                                  context,
                                  appState: widget.appState,
                                  accent: widget.accent,
                                  showMockOption: true,
                                  showUnifiedOption: true,
                                  onSelectUnified: _enableUnifiedInbox,
                                  onSelectAccount: _disableUnifiedInbox,
                                ),
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

class _WideLayout extends StatelessWidget {
  const _WideLayout({
    required this.appState,
    required this.account,
    required this.accent,
    required this.provider,
    required this.listCurrentUserEmail,
    required this.detailCurrentUserEmail,
    required this.selectedThreadIndex,
    required this.onThreadSelected,
    required this.selectedFolderIndex,
    required this.onFolderSelected,
    required this.sidebarCollapsed,
    required this.onSidebarToggle,
    required this.onAccountTap,
    required this.navIndex,
    required this.onNavSelected,
    required this.onSettingsTap,
    required this.onSettingsClose,
    required this.showSettings,
    required this.threadFocused,
    required this.threadListFocusNode,
    required this.threadDetailFocusNode,
    required this.threadDetailScrollController,
    required this.onThreadDetailKeyEvent,
    required this.threadPanelFraction,
    required this.threadPanelOpen,
    required this.onThreadPanelResize,
    required this.onThreadPanelResizeEnd,
    required this.onThreadPanelOpen,
    required this.onThreadPanelClose,
    required this.onCompose,
    required this.searchFocusNode,
    required this.replyController,
    required this.selectedMessageIndex,
    required this.onMessageSelected,
  });

  final AppState appState;
  final EmailAccount account;
  final Color accent;
  final EmailProvider provider;
  final String listCurrentUserEmail;
  final String detailCurrentUserEmail;
  final int selectedThreadIndex;
  final ValueChanged<int> onThreadSelected;
  final int selectedFolderIndex;
  final ValueChanged<int> onFolderSelected;
  final bool sidebarCollapsed;
  final VoidCallback onSidebarToggle;
  final VoidCallback onAccountTap;
  final int navIndex;
  final ValueChanged<int> onNavSelected;
  final VoidCallback onSettingsTap;
  final VoidCallback onSettingsClose;
  final bool showSettings;
  final bool threadFocused;
  final FocusNode threadListFocusNode;
  final FocusNode threadDetailFocusNode;
  final ScrollController threadDetailScrollController;
  final KeyEventResult Function(KeyEvent event) onThreadDetailKeyEvent;
  final double threadPanelFraction;
  final bool threadPanelOpen;
  final ValueChanged<double> onThreadPanelResize;
  final VoidCallback onThreadPanelResizeEnd;
  final VoidCallback onThreadPanelOpen;
  final VoidCallback onThreadPanelClose;
  final VoidCallback onCompose;
  final FocusNode searchFocusNode;
  final InlineReplyController replyController;
  final int selectedMessageIndex;
  final ValueChanged<int> onMessageSelected;

  @override
  Widget build(BuildContext context) {
    final threads = provider.threads;
    final folderSections = provider.folderSections;
    final safeIndex = threads.isEmpty
        ? 0
        : _selectedIndex(selectedThreadIndex, threads.length);
    final selectedThread = threads.isEmpty ? null : threads[safeIndex];
    final pinnedItems = _pinnedItems(
      folderSections,
      context.tidingsSettings.pinnedFolderPaths,
    );
    final padding = EdgeInsets.all(context.gutter(16));
    final listOpacity = threadFocused ? 0.6 : 1.0;

    return Padding(
      padding: padding,
      child: PageReveal(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedOpacity(
              opacity: listOpacity,
              duration: const Duration(milliseconds: 180),
              child: sidebarCollapsed
                  ? SizedBox(
                      width: context.space(72),
                      child: _SidebarRail(
                        account: account,
                        accent: accent,
                        mailboxItems: _mailboxItems(folderSections),
                        pinnedItems: pinnedItems,
                        selectedIndex: selectedFolderIndex,
                        onSelected: onFolderSelected,
                        onExpand: onSidebarToggle,
                        onAccountTap: onAccountTap,
                        onSettingsTap: onSettingsTap,
                        onCompose: onCompose,
                      ),
                    )
                  : SizedBox(
                      width: context.space(240),
                      child: SidebarPanel(
                        account: account,
                        accent: accent,
                        provider: provider,
                        sections: folderSections,
                        selectedIndex: selectedFolderIndex,
                        onSelected: onFolderSelected,
                        onSettingsTap: onSettingsTap,
                        onCollapse: onSidebarToggle,
                        onAccountTap: onAccountTap,
                        onCompose: onCompose,
                      ),
                    ),
            ),
            SizedBox(width: context.space(16)),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final detailOpen = showSettings || threadPanelOpen;
                  final handleWidth = context.space(12);
                  if (!detailOpen) {
                    final availableWidth = constraints.maxWidth;
                    return Row(
                      children: [
                        Expanded(
                          child: AnimatedOpacity(
                            opacity: listOpacity,
                            duration: const Duration(milliseconds: 180),
                            child: Listener(
                              onPointerDown: (_) =>
                                  threadListFocusNode.requestFocus(),
                              child: Focus(
                                focusNode: threadListFocusNode,
                                child: ThreadListPanel(
                                  accent: accent,
                                  provider: provider,
                                  selectedIndex: selectedThreadIndex,
                                  onSelected: onThreadSelected,
                                  isCompact: false,
                                  currentUserEmail: listCurrentUserEmail,
                                  searchFocusNode: searchFocusNode,
                                ),
                              ),
                            ),
                          ),
                        ),
                        IgnorePointer(
                          ignoring: false,
                          child: _ThreadPanelHint(
                            accent: accent,
                            width: handleWidth,
                            onTap: onThreadPanelOpen,
                            onDragUpdate: (delta) {
                              onThreadPanelOpen();
                              final nextFraction =
                                  (threadPanelFraction +
                                          (-delta / availableWidth))
                                      .clamp(0.3, 0.8);
                              onThreadPanelResize(nextFraction);
                            },
                            onDragEnd: onThreadPanelResizeEnd,
                          ),
                        ),
                      ],
                    );
                  }

                  final availableWidth = constraints.maxWidth - handleWidth;
                  final minListWidth = context.space(280);
                  final minDetailWidth = context.space(260);
                  final snapThreshold = context.space(300);
                  final maxDetailWidth = availableWidth - minListWidth;
                  final boundedMaxDetailWidth = maxDetailWidth < minDetailWidth
                      ? minDetailWidth
                      : maxDetailWidth;
                  final desiredDetailWidth =
                      availableWidth * threadPanelFraction;
                  final detailWidth = desiredDetailWidth.clamp(
                    minDetailWidth,
                    boundedMaxDetailWidth,
                  );
                  final listWidth = availableWidth - detailWidth;

                  void handleResize(double delta) {
                    final nextDetailWidth = detailWidth - delta;
                    if (!showSettings && nextDetailWidth <= snapThreshold) {
                      onThreadPanelClose();
                      return;
                    }
                    final clampedWidth = nextDetailWidth.clamp(
                      minDetailWidth,
                      boundedMaxDetailWidth,
                    );
                    onThreadPanelResize(clampedWidth / availableWidth);
                  }

                  return Row(
                    children: [
                      SizedBox(
                        width: listWidth,
                        child: AnimatedOpacity(
                          opacity: listOpacity,
                          duration: const Duration(milliseconds: 180),
                          child: Listener(
                            onPointerDown: (_) =>
                                threadListFocusNode.requestFocus(),
                            child: Focus(
                              focusNode: threadListFocusNode,
                              child: ThreadListPanel(
                                accent: accent,
                                provider: provider,
                                selectedIndex: selectedThreadIndex,
                                onSelected: onThreadSelected,
                                isCompact: false,
                                currentUserEmail: listCurrentUserEmail,
                                searchFocusNode: searchFocusNode,
                              ),
                            ),
                          ),
                        ),
                      ),
                      _ResizeHandle(
                        onDragUpdate: handleResize,
                        onDragEnd: onThreadPanelResizeEnd,
                      ),
                      SizedBox(
                        width: detailWidth,
                        child: showSettings
                            ? SettingsPanel(
                                accent: accent,
                                appState: appState,
                                onClose: onSettingsClose,
                              )
                            : AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeInCubic,
                                transitionBuilder: (child, animation) =>
                                    SizeTransition(
                                      sizeFactor: animation,
                                      axisAlignment: -1,
                                      child: FadeTransition(
                                        opacity: animation,
                                        child: child,
                                      ),
                                    ),
                                child: selectedThread == null
                                    ? const SizedBox.shrink()
                                    : Listener(
                                        onPointerDown: (_) =>
                                            threadDetailFocusNode
                                                .requestFocus(),
                                        child: Focus(
                                          focusNode: threadDetailFocusNode,
                                          onKeyEvent: (node, event) =>
                                              onThreadDetailKeyEvent(event),
                                          child: CurrentThreadPanel(
                                            key: ValueKey(selectedThread.id),
                                            accent: accent,
                                            thread: selectedThread,
                                            provider: provider,
                                            isCompact: false,
                                            currentUserEmail:
                                                detailCurrentUserEmail,
                                            replyController: replyController,
                                            selectedMessageIndex:
                                                selectedMessageIndex,
                                            onMessageSelected:
                                                onMessageSelected,
                                            isFocused: threadFocused,
                                            parentFocusNode:
                                                threadDetailFocusNode,
                                            scrollController:
                                                threadDetailScrollController,
                                          ),
                                        ),
                                      ),
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

int _selectedIndex(int index, int length) {
  if (length <= 0) {
    return 0;
  }
  return index.clamp(0, length - 1);
}

List<FolderItem> _mailboxItems(List<FolderSection> sections) {
  for (final section in sections) {
    if (section.kind == FolderSectionKind.mailboxes) {
      return section.items;
    }
  }
  return const [];
}

List<FolderItem> _pinnedItems(
  List<FolderSection> sections,
  Set<String> pinnedPaths,
) {
  if (pinnedPaths.isEmpty) {
    return const [];
  }
  final items = <FolderItem>[];
  for (final section in sections) {
    for (final item in section.items) {
      if (pinnedPaths.contains(item.path)) {
        items.add(item);
      }
    }
  }
  return items;
}

const List<FolderItem> _fallbackRailItems = [
  FolderItem(index: 0, name: 'Inbox', path: 'INBOX', icon: Icons.inbox_rounded),
  FolderItem(
    index: 1,
    name: 'Archive',
    path: 'Archive',
    icon: Icons.archive_rounded,
  ),
  FolderItem(
    index: 2,
    name: 'Drafts',
    path: 'Drafts',
    icon: Icons.drafts_rounded,
  ),
  FolderItem(index: 3, name: 'Sent', path: 'Sent', icon: Icons.send_rounded),
];

class _ResizeHandle extends StatelessWidget {
  const _ResizeHandle({required this.onDragUpdate, this.onDragEnd});

  final ValueChanged<double> onDragUpdate;
  final VoidCallback? onDragEnd;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: (details) => onDragUpdate(details.delta.dx),
        onHorizontalDragEnd: (_) => onDragEnd?.call(),
        child: SizedBox(
          width: context.space(12),
          child: Center(
            child: Container(
              width: 3,
              height: context.space(48),
              decoration: BoxDecoration(
                color: ColorTokens.border(context, 0.2),
                borderRadius: BorderRadius.circular(context.radius(8)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ThreadPanelHint extends StatelessWidget {
  const _ThreadPanelHint({
    required this.accent,
    required this.width,
    required this.onTap,
    required this.onDragUpdate,
    this.onDragEnd,
  });

  final Color accent;
  final double width;
  final VoidCallback onTap;
  final ValueChanged<double> onDragUpdate;
  final VoidCallback? onDragEnd;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: onTap,
        onHorizontalDragUpdate: (details) => onDragUpdate(details.delta.dx),
        onHorizontalDragEnd: (_) => onDragEnd?.call(),
        child: SizedBox(
          width: width,
          child: Center(
            child: Container(
              width: 3,
              height: context.space(48),
              decoration: BoxDecoration(
                color: ColorTokens.border(context, 0.2),
                borderRadius: BorderRadius.circular(context.radius(8)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactLayout extends StatelessWidget {
  const _CompactLayout({
    required this.account,
    required this.accent,
    required this.provider,
    required this.selectedThreadIndex,
    required this.onThreadSelected,
    required this.selectedFolderIndex,
    required this.onFolderSelected,
    required this.onAccountTap,
    required this.searchFocusNode,
    required this.threadListFocusNode,
    required this.listCurrentUserEmail,
    required this.currentUserEmailForThread,
  });

  final EmailAccount account;
  final Color accent;
  final EmailProvider provider;
  final int selectedThreadIndex;
  final ValueChanged<int> onThreadSelected;
  final int selectedFolderIndex;
  final ValueChanged<int> onFolderSelected;
  final VoidCallback onAccountTap;
  final FocusNode searchFocusNode;
  final FocusNode threadListFocusNode;
  final String listCurrentUserEmail;
  final String Function(EmailThread thread) currentUserEmailForThread;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            context.gutter(16),
            context.space(12),
            context.gutter(16),
            0,
          ),
          child: PageReveal(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CompactHeader(
                  account: account,
                  accent: accent,
                  provider: provider,
                  sections: provider.folderSections,
                  selectedFolderIndex: selectedFolderIndex,
                  onFolderSelected: onFolderSelected,
                  onAccountTap: onAccountTap,
                ),
                SizedBox(height: context.space(16)),
                ThreadSearchRow(accent: accent, focusNode: searchFocusNode),
                SizedBox(height: context.space(8)),
                Expanded(
                  child: Listener(
                    onPointerDown: (_) => threadListFocusNode.requestFocus(),
                    child: Focus(
                      focusNode: threadListFocusNode,
                      child: ThreadListPanel(
                        accent: accent,
                        provider: provider,
                        selectedIndex: selectedThreadIndex,
                        onSelected: (index) {
                          onThreadSelected(index);
                          final thread = provider.threads[index];
                          final currentUserEmail = currentUserEmailForThread(
                            thread,
                          );
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => ThreadScreen(
                                accent: accent,
                                thread: thread,
                                provider: provider,
                                currentUserEmail: currentUserEmail,
                              ),
                            ),
                          );
                        },
                        isCompact: true,
                        currentUserEmail: listCurrentUserEmail,
                        searchFocusNode: searchFocusNode,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 0,
          bottom: 0,
          left: 0,
          width: context.space(18),
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragEnd: (details) {
              final velocity = details.primaryVelocity ?? 0;
              if (velocity > 300) {
                _showFolderSheet(
                  context,
                  accent: accent,
                  provider: provider,
                  sections: provider.folderSections,
                  selectedFolderIndex: selectedFolderIndex,
                  onFolderSelected: onFolderSelected,
                );
              }
            },
            onTap: () {
              _showFolderSheet(
                context,
                accent: accent,
                provider: provider,
                sections: provider.folderSections,
                selectedFolderIndex: selectedFolderIndex,
                onFolderSelected: onFolderSelected,
              );
            },
          ),
        ),
      ],
    );
  }
}

class SidebarPanel extends StatelessWidget {
  const SidebarPanel({
    super.key,
    required this.account,
    required this.accent,
    required this.provider,
    required this.sections,
    required this.selectedIndex,
    required this.onSelected,
    required this.onSettingsTap,
    required this.onCollapse,
    required this.onAccountTap,
    required this.onCompose,
  });

  final EmailAccount account;
  final Color accent;
  final EmailProvider provider;
  final List<FolderSection> sections;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onSettingsTap;
  final VoidCallback onCollapse;
  final VoidCallback onAccountTap;
  final VoidCallback onCompose;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      borderRadius: BorderRadius.circular(context.radius(22)),
      padding: EdgeInsets.fromLTRB(
        context.space(14),
        context.space(16),
        context.space(14),
        context.space(12),
      ),
      variant: GlassVariant.panel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onAccountTap,
                  child: Row(
                    children: [
                      AccountAvatar(
                        name: account.displayName,
                        accent: accent,
                        showRing: true,
                      ),
                      SizedBox(width: context.space(10)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              account.displayName,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              account.email,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: ColorTokens.textSecondary(context),
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                onPressed: onCollapse,
                icon: const Icon(Icons.chevron_left_rounded),
                tooltip: 'Collapse',
              ),
            ],
          ),
          SizedBox(height: context.space(14)),
          Expanded(
            child: FolderList(
              accent: accent,
              provider: provider,
              sections: sections,
              selectedIndex: selectedIndex,
              onSelected: onSelected,
            ),
          ),
          SizedBox(height: context.space(8)),
          Row(
            children: [
              IconButton(
                onPressed: onSettingsTap,
                icon: const Icon(Icons.settings_rounded),
                tooltip: 'Settings',
              ),
              const Spacer(),
              GlassActionButton(
                accent: accent,
                label: 'Compose',
                icon: Icons.edit_rounded,
                onTap: onCompose,
                tooltip:
                    'Compose (${context.tidingsSettings.shortcutLabel(ShortcutAction.compose, includeSecondary: false)})',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class FolderList extends StatelessWidget {
  const FolderList({
    super.key,
    required this.accent,
    required this.provider,
    required this.sections,
    required this.selectedIndex,
    required this.onSelected,
  });

  final Color accent;
  final EmailProvider provider;
  final List<FolderSection> sections;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final settings = context.tidingsSettings;
    final visibleSections = settings.showFolderLabels
        ? sections
        : sections
              .where((section) => section.kind != FolderSectionKind.labels)
              .toList();

    return ListView.builder(
      itemCount: visibleSections.length,
      itemBuilder: (context, sectionIndex) {
        final section = visibleSections[sectionIndex];
        return _FolderSection(
          section: section,
          accent: accent,
          isFolderLoading: provider.isFolderLoading,
          selectedIndex: selectedIndex,
          onSelected: onSelected,
        );
      },
    );
  }
}

class _FolderSheet extends StatelessWidget {
  const _FolderSheet({
    required this.accent,
    required this.provider,
    required this.sections,
    required this.selectedFolderIndex,
    required this.onFolderSelected,
  });

  final Color accent;
  final EmailProvider provider;
  final List<FolderSection> sections;
  final int selectedFolderIndex;
  final ValueChanged<int> onFolderSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(context.gutter(16)),
        child: GlassPanel(
          borderRadius: BorderRadius.circular(context.radius(24)),
          padding: EdgeInsets.all(context.space(16)),
          variant: GlassVariant.sheet,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Folders', style: Theme.of(context).textTheme.titleLarge),
              SizedBox(height: context.space(12)),
              Expanded(
                child: FolderList(
                  accent: accent,
                  provider: provider,
                  sections: sections,
                  selectedIndex: selectedFolderIndex,
                  onSelected: (index) {
                    onFolderSelected(index);
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FolderSection extends StatelessWidget {
  const _FolderSection({
    required this.section,
    required this.accent,
    required this.isFolderLoading,
    required this.selectedIndex,
    required this.onSelected,
  });

  final FolderSection section;
  final Color accent;
  final bool Function(String path) isFolderLoading;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.space(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: ColorTokens.textSecondary(context, 0.6),
              letterSpacing: 0.6,
            ),
          ),
          SizedBox(height: context.space(8)),
          ...section.items.map((item) {
            return _FolderRow(
              item: item,
              accent: accent,
              isLoading: isFolderLoading(item.path),
              selected: item.index == selectedIndex,
              onTap: () => onSelected(item.index),
            );
          }),
        ],
      ),
    );
  }
}

class _FolderRow extends StatefulWidget {
  const _FolderRow({
    required this.item,
    required this.accent,
    required this.isLoading,
    required this.selected,
    required this.onTap,
  });

  final FolderItem item;
  final Color accent;
  final bool isLoading;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_FolderRow> createState() => _FolderRowState();
}

class _FolderRowState extends State<_FolderRow> {
  bool _hovered = false;

  void _setHovered(bool value) {
    if (_hovered == value) {
      return;
    }
    setState(() => _hovered = value);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.tidingsSettings;
    final unread = widget.item.unreadCount > 0;
    final showUnreadCounts = settings.showFolderUnreadCounts;
    final isPinned = settings.isFolderPinned(widget.item.path);
    final showPin = _hovered || isPinned;
    final baseColor = Theme.of(context).colorScheme.onSurface;
    final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: unread ? baseColor : baseColor.withValues(alpha: 0.65),
      fontWeight: unread ? FontWeight.w600 : FontWeight.w500,
    );

    return MouseRegion(
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          margin: EdgeInsets.only(bottom: context.space(4)),
          padding: EdgeInsets.fromLTRB(
            context.space(6) + widget.item.depth * context.space(12),
            context.space(4),
            context.space(6),
            context.space(4),
          ),
          decoration: BoxDecoration(
            color: widget.selected
                ? widget.accent.withValues(alpha: 0.14)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(context.radius(12)),
          ),
          child: Row(
            children: [
              if (widget.selected)
                Container(
                  width: 2,
                  height: context.space(12),
                  margin: EdgeInsets.only(right: context.space(8)),
                  decoration: BoxDecoration(
                    color: widget.accent,
                    borderRadius: BorderRadius.circular(context.radius(8)),
                  ),
                )
              else
                SizedBox(width: context.space(8)),
              if (widget.item.icon != null) ...[
                Icon(
                  widget.item.icon,
                  size: 15,
                  color: unread
                      ? baseColor.withValues(alpha: 0.8)
                      : baseColor.withValues(alpha: 0.55),
                ),
                SizedBox(width: context.space(6)),
              ],
              Expanded(
                child: Text(
                  widget.item.name,
                  style: textStyle,
                  maxLines: 2,
                  overflow: TextOverflow.visible,
                  softWrap: true,
                ),
              ),
              if (widget.isLoading)
                Padding(
                  padding: EdgeInsets.only(right: context.space(6)),
                  child: SizedBox(
                    width: context.space(12),
                    height: context.space(12),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        widget.accent.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ),
              IgnorePointer(
                ignoring: !showPin,
                child: AnimatedOpacity(
                  opacity: showPin ? 1 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: IconButton(
                    onPressed: () =>
                        settings.toggleFolderPinned(widget.item.path),
                    icon: Icon(
                      isPinned
                          ? Icons.push_pin_rounded
                          : Icons.push_pin_outlined,
                      size: 14,
                    ),
                    color: isPinned
                        ? widget.accent
                        : ColorTokens.textSecondary(context, 0.7),
                    tooltip: isPinned ? 'Unpin from rail' : 'Pin to rail',
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints.tightFor(
                      width: context.space(24),
                      height: context.space(24),
                    ),
                  ),
                ),
              ),
              if (unread && showUnreadCounts)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.space(6),
                    vertical: context.space(1),
                  ),
                  decoration: BoxDecoration(
                    color: widget.accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(context.radius(999)),
                  ),
                  child: Text(
                    widget.item.unreadCount.toString(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: widget.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarRail extends StatelessWidget {
  const _SidebarRail({
    required this.account,
    required this.accent,
    required this.mailboxItems,
    required this.pinnedItems,
    required this.selectedIndex,
    required this.onSelected,
    required this.onExpand,
    required this.onAccountTap,
    required this.onSettingsTap,
    required this.onCompose,
  });

  final EmailAccount account;
  final Color accent;
  final List<FolderItem> mailboxItems;
  final List<FolderItem> pinnedItems;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onExpand;
  final VoidCallback onAccountTap;
  final VoidCallback onSettingsTap;
  final VoidCallback onCompose;

  @override
  Widget build(BuildContext context) {
    final baseItems = mailboxItems.isEmpty ? _fallbackRailItems : mailboxItems;
    final items = <FolderItem>[];
    for (final item in baseItems) {
      items.add(item);
    }
    for (final item in pinnedItems) {
      if (items.any((existing) => existing.path == item.path)) {
        continue;
      }
      items.add(item);
    }
    return GlassPanel(
      borderRadius: BorderRadius.circular(context.radius(22)),
      padding: EdgeInsets.symmetric(
        vertical: context.space(12),
        horizontal: context.space(8),
      ),
      variant: GlassVariant.panel,
      child: Column(
        children: [
          AccountAvatar(
            name: account.displayName,
            accent: accent,
            onTap: onAccountTap,
          ),
          SizedBox(height: context.space(16)),
          for (final item in items.take(6))
            _RailIconButton(
              icon: item.icon ?? Icons.mail_outline_rounded,
              selected: selectedIndex == item.index,
              accent: accent,
              onTap: () => onSelected(item.index),
              label: item.name,
            ),
          const Spacer(),
          GlassPanel(
            borderRadius: BorderRadius.circular(context.radius(16)),
            padding: EdgeInsets.all(context.space(4)),
            variant: GlassVariant.pill,
            accent: accent,
            selected: true,
            child: IconButton(
              onPressed: onCompose,
              icon: const Icon(Icons.edit_rounded),
              tooltip:
                  'Compose (${context.tidingsSettings.shortcutLabel(ShortcutAction.compose, includeSecondary: false)})',
            ),
          ),
          SizedBox(height: context.space(8)),
          IconButton(
            onPressed: onSettingsTap,
            icon: const Icon(Icons.settings_rounded),
            tooltip: 'Settings',
          ),
          IconButton(
            onPressed: onExpand,
            icon: const Icon(Icons.chevron_right_rounded),
            tooltip: 'Expand',
          ),
        ],
      ),
    );
  }
}

class _RailIconButton extends StatelessWidget {
  const _RailIconButton({
    required this.icon,
    required this.selected,
    required this.accent,
    required this.onTap,
    required this.label,
  });

  final IconData icon;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon),
      color: selected ? accent : Theme.of(context).colorScheme.onSurface,
      tooltip: label,
    );
  }
}

class _CompactHeader extends StatelessWidget {
  const _CompactHeader({
    required this.account,
    required this.accent,
    required this.provider,
    required this.sections,
    required this.selectedFolderIndex,
    required this.onFolderSelected,
    required this.onAccountTap,
  });

  final EmailAccount account;
  final Color accent;
  final EmailProvider provider;
  final List<FolderSection> sections;
  final int selectedFolderIndex;
  final ValueChanged<int> onFolderSelected;
  final VoidCallback onAccountTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GlassPanel(
          borderRadius: BorderRadius.circular(context.radius(18)),
          padding: EdgeInsets.all(context.space(6)),
          variant: GlassVariant.pill,
          child: AccountAvatar(name: account.displayName, accent: accent),
        ),
        SizedBox(width: context.space(12)),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Welcome back', style: Theme.of(context).textTheme.labelLarge),
            Text(account.email, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
        const Spacer(),
        IconButton(
          onPressed: onAccountTap,
          icon: const Icon(Icons.people_alt_rounded),
          tooltip: 'Accounts',
        ),
        IconButton(
          onPressed: () => _showFolderSheet(
            context,
            accent: accent,
            provider: provider,
            sections: sections,
            selectedFolderIndex: selectedFolderIndex,
            onFolderSelected: onFolderSelected,
          ),
          icon: const Icon(Icons.folder_open_rounded),
          tooltip: 'Folders',
        ),
      ],
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.accent,
    required this.appState,
    this.onClose,
  });

  final Color accent;
  final AppState appState;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(context.gutter(16)),
      child: SettingsPanel(
        accent: accent,
        appState: appState,
        onClose: onClose,
      ),
    );
  }
}

class SettingsPanel extends StatelessWidget {
  const SettingsPanel({
    super.key,
    required this.accent,
    required this.appState,
    this.onClose,
  });

  final Color accent;
  final AppState appState;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final segmentedStyle = ButtonStyle(
      padding: WidgetStatePropertyAll(
        EdgeInsets.symmetric(
          horizontal: context.space(10),
          vertical: context.space(6),
        ),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(context.radius(12)),
        ),
      ),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return accent.withValues(alpha: 0.18);
        }
        return ColorTokens.cardFill(context, 0.08);
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return accent;
        }
        return ColorTokens.textSecondary(context, 0.7);
      }),
      side: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return BorderSide(color: accent.withValues(alpha: 0.5));
        }
        return BorderSide(color: ColorTokens.border(context, 0.1));
      }),
    );

    return GlassPanel(
      borderRadius: BorderRadius.circular(context.radius(28)),
      padding: EdgeInsets.all(context.space(14)),
      variant: GlassVariant.sheet,
      child: DefaultTabController(
        length: 6,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Settings',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                if (onClose != null)
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Close settings',
                  ),
              ],
            ),
            SizedBox(height: context.space(12)),
            const SettingsTabBar(
              tabs: [
                'Appearance',
                'Layout',
                'Threads',
                'Folders',
                'Accounts',
                'Keyboard',
              ],
            ),
            SizedBox(height: context.space(12)),
            Expanded(
              child: TabBarView(
                children: [
                  SettingsTab(
                    child: _AppearanceSettings(
                      accent: accent,
                      segmentedStyle: segmentedStyle,
                    ),
                  ),
                  SettingsTab(
                    child: _LayoutSettings(segmentedStyle: segmentedStyle),
                  ),
                  SettingsTab(
                    child: _ThreadsSettings(segmentedStyle: segmentedStyle),
                  ),
                  SettingsTab(child: _FoldersSettings(accent: accent)),
                  SettingsTab(
                    child: _AccountsSettings(
                      appState: appState,
                      accent: accent,
                    ),
                  ),
                  const SettingsTab(child: _KeyboardSettings()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppearanceSettings extends StatelessWidget {
  const _AppearanceSettings({
    required this.accent,
    required this.segmentedStyle,
  });

  final Color accent;
  final ButtonStyle segmentedStyle;

  @override
  Widget build(BuildContext context) {
    final settings = context.tidingsSettings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Appearance', style: Theme.of(context).textTheme.titleLarge),
        SizedBox(height: context.space(12)),
        SettingRow(
          title: 'Theme',
          subtitle: 'Follow system appearance or set manually.',
          trailing: SegmentedButton<ThemeMode>(
            style: segmentedStyle,
            segments: const [
              ButtonSegment(value: ThemeMode.light, label: Text('Light')),
              ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
              ButtonSegment(value: ThemeMode.system, label: Text('System')),
            ],
            selected: {settings.themeMode},
            onSelectionChanged: (selection) {
              settings.setThemeMode(selection.first);
            },
          ),
        ),
        SizedBox(height: context.space(16)),
        SettingRow(
          title: 'Theme palette',
          subtitle: 'Neutral or account-accent gradients.',
          trailing: SegmentedButton<ThemePaletteSource>(
            style: segmentedStyle,
            segments: ThemePaletteSource.values
                .map(
                  (source) =>
                      ButtonSegment(value: source, label: Text(source.label)),
                )
                .toList(),
            selected: {settings.paletteSource},
            onSelectionChanged: (selection) {
              settings.setPaletteSource(selection.first);
            },
          ),
        ),
      ],
    );
  }
}

class _LayoutSettings extends StatelessWidget {
  const _LayoutSettings({required this.segmentedStyle});

  final ButtonStyle segmentedStyle;

  @override
  Widget build(BuildContext context) {
    final settings = context.tidingsSettings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Layout', style: Theme.of(context).textTheme.titleLarge),
        SizedBox(height: context.space(12)),
        SettingRow(
          title: 'Layout density',
          subtitle: 'Compactness and margins in one setting.',
          trailing: SegmentedButton<LayoutDensity>(
            style: segmentedStyle,
            segments: LayoutDensity.values
                .map(
                  (density) =>
                      ButtonSegment(value: density, label: Text(density.label)),
                )
                .toList(),
            selected: {settings.layoutDensity},
            onSelectionChanged: (selection) {
              settings.setLayoutDensity(selection.first);
            },
          ),
        ),
        SizedBox(height: context.space(16)),
        SettingRow(
          title: 'Corner radius',
          subtitle: 'Dial in how rounded the UI feels.',
          trailing: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 420;
              final children = CornerRadiusStyle.values
                  .map(
                    (style) => SizedBox(
                      width: isNarrow ? 160 : 120,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: context.space(4),
                          vertical: context.space(4),
                        ),
                        child: CornerRadiusOption(
                          label: style.label,
                          radius: context.space(18) * style.scale,
                          selected: settings.cornerRadiusStyle == style,
                          onTap: () => settings.setCornerRadiusStyle(style),
                        ),
                      ),
                    ),
                  )
                  .toList();
              return Wrap(
                spacing: context.space(4),
                runSpacing: context.space(4),
                children: children,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ThreadsSettings extends StatelessWidget {
  const _ThreadsSettings({required this.segmentedStyle});

  final ButtonStyle segmentedStyle;

  @override
  Widget build(BuildContext context) {
    final settings = context.tidingsSettings;
    final accent = Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Threads', style: Theme.of(context).textTheme.titleLarge),
        SizedBox(height: context.space(12)),
        SettingRow(
          title: 'Auto-expand unread',
          subtitle: 'Open unread threads to show the latest message.',
          trailing: AccentSwitch(
            accent: accent,
            value: settings.autoExpandUnread,
            onChanged: settings.setAutoExpandUnread,
          ),
        ),
        SizedBox(height: context.space(16)),
        SettingRow(
          title: 'Auto-expand latest',
          subtitle: 'Keep the newest thread expanded in the list.',
          trailing: AccentSwitch(
            accent: accent,
            value: settings.autoExpandLatest,
            onChanged: settings.setAutoExpandLatest,
          ),
        ),
        SizedBox(height: context.space(16)),
        SettingRow(
          title: 'Hide subject lines',
          subtitle: 'Show only the message body in thread view.',
          trailing: AccentSwitch(
            accent: accent,
            value: settings.hideThreadSubjects,
            onChanged: settings.setHideThreadSubjects,
          ),
        ),
        SizedBox(height: context.space(16)),
        SettingRow(
          title: 'Hide yourself in thread list',
          subtitle: 'Remove your address from sender rows.',
          trailing: AccentSwitch(
            accent: accent,
            value: settings.hideSelfInThreadList,
            onChanged: settings.setHideSelfInThreadList,
          ),
        ),
        SizedBox(height: context.space(24)),
        SettingsSubheader(title: 'MESSAGE PREVIEW'),
        SizedBox(height: context.space(12)),
        SettingRow(
          title: 'Collapse mode',
          subtitle: 'How to shorten long messages in collapsed view.',
          trailing: SegmentedButton<MessageCollapseMode>(
            style: segmentedStyle,
            segments: MessageCollapseMode.values
                .map(
                  (mode) => ButtonSegment(value: mode, label: Text(mode.label)),
                )
                .toList(),
            selected: {settings.messageCollapseMode},
            onSelectionChanged: (selected) =>
                settings.setMessageCollapseMode(selected.first),
          ),
        ),
        if (settings.messageCollapseMode == MessageCollapseMode.maxLines) ...[
          SizedBox(height: context.space(16)),
          SettingRow(
            title: 'Max lines',
            subtitle: 'Number of lines to show before truncating.',
            trailing: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: settings.collapsedMaxLines,
                onChanged: (value) {
                  if (value != null) {
                    settings.setCollapsedMaxLines(value);
                  }
                },
                items: [4, 6, 8, 10, 12, 15, 20]
                    .map(
                      (n) =>
                          DropdownMenuItem(value: n, child: Text('$n lines')),
                    )
                    .toList(),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _FoldersSettings extends StatelessWidget {
  const _FoldersSettings({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    final settings = context.tidingsSettings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Folders', style: Theme.of(context).textTheme.titleLarge),
        SizedBox(height: context.space(12)),
        SettingRow(
          title: 'Show labels',
          subtitle: 'Include the Labels section in the sidebar.',
          trailing: AccentSwitch(
            accent: accent,
            value: settings.showFolderLabels,
            onChanged: settings.setShowFolderLabels,
          ),
        ),
        SizedBox(height: context.space(16)),
        SettingRow(
          title: 'Unread counts',
          subtitle: 'Show unread badge counts next to folders.',
          trailing: AccentSwitch(
            accent: accent,
            value: settings.showFolderUnreadCounts,
            onChanged: settings.setShowFolderUnreadCounts,
          ),
        ),
      ],
    );
  }
}

class _AccountsSettings extends StatelessWidget {
  const _AccountsSettings({required this.appState, required this.accent});

  final AppState appState;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    if (appState.accounts.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Accounts', style: Theme.of(context).textTheme.titleLarge),
          SizedBox(height: context.space(12)),
          Text(
            'No account selected.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: ColorTokens.textSecondary(context),
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Accounts', style: Theme.of(context).textTheme.titleLarge),
        SizedBox(height: context.space(8)),
        Text(
          'Manage per-account settings and verify connections.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: ColorTokens.textSecondary(context),
          ),
        ),
        SizedBox(height: context.space(10)),
        OutlinedButton.icon(
          onPressed: () async {
            final error = await appState.openConfigDirectory();
            if (!context.mounted) {
              return;
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  error == null
                      ? 'Opened settings directory.'
                      : 'Unable to open settings directory: $error',
                ),
              ),
            );
          },
          icon: const Icon(Icons.folder_open_rounded),
          label: const Text('Open Settings File Directory'),
        ),
        SizedBox(height: context.space(12)),
        for (final account in appState.accounts) ...[
          _AccountSection(
            appState: appState,
            account: account,
            accent: accent,
            defaultExpanded: appState.accounts.length < 3,
          ),
          SizedBox(height: context.space(16)),
        ],
      ],
    );
  }
}

class _KeyboardSettings extends StatelessWidget {
  const _KeyboardSettings();

  @override
  Widget build(BuildContext context) {
    final settings = context.tidingsSettings;
    final navigation = <ShortcutAction>[
      ShortcutAction.navigateNext,
      ShortcutAction.navigatePrev,
      ShortcutAction.openThread,
      ShortcutAction.toggleSidebar,
      ShortcutAction.goTo,
      ShortcutAction.goToAccount,
      ShortcutAction.focusSearch,
      ShortcutAction.openSettings,
    ];
    final compose = <ShortcutAction>[
      ShortcutAction.compose,
      ShortcutAction.reply,
      ShortcutAction.replyAll,
      ShortcutAction.forward,
      ShortcutAction.sendMessage,
    ];
    final mailbox = <ShortcutAction>[
      ShortcutAction.archive,
      ShortcutAction.commandPalette,
      ShortcutAction.showShortcuts,
    ];

    Widget buildSection(String title, List<ShortcutAction> actions) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SettingsSubheader(title: title),
          SizedBox(height: context.space(10)),
          for (final action in actions) ...[
            _ShortcutRow(
              definition: definitionFor(action),
              primary: settings.shortcutFor(action),
              secondary: settings.secondaryShortcutFor(action),
              onPrimaryChanged: (value) => settings.setShortcut(action, value),
              onSecondaryChanged: (value) =>
                  settings.setShortcut(action, value, secondary: true),
            ),
            SizedBox(height: context.space(14)),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Keyboard', style: Theme.of(context).textTheme.titleLarge),
        SizedBox(height: context.space(12)),
        Text(
          'Edit keyboard shortcuts for power navigation.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: ColorTokens.textSecondary(context),
          ),
        ),
        SizedBox(height: context.space(16)),
        buildSection('Navigation', navigation),
        SizedBox(height: context.space(10)),
        buildSection('Compose', compose),
        SizedBox(height: context.space(10)),
        buildSection('Mailbox', mailbox),
      ],
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow({
    required this.definition,
    required this.primary,
    required this.secondary,
    required this.onPrimaryChanged,
    required this.onSecondaryChanged,
  });

  final ShortcutDefinition definition;
  final KeyboardShortcut primary;
  final KeyboardShortcut? secondary;
  final ValueChanged<KeyboardShortcut> onPrimaryChanged;
  final ValueChanged<KeyboardShortcut> onSecondaryChanged;

  @override
  Widget build(BuildContext context) {
    final secondaryShortcut = secondary ?? definition.secondaryDefault;
    return SettingRow(
      title: definition.label,
      subtitle: definition.description,
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _ShortcutSlot(
            label: definition.secondaryDefault != null ? 'Primary' : null,
            child: ShortcutRecorder(
              shortcut: primary,
              onChanged: onPrimaryChanged,
            ),
          ),
          if (secondaryShortcut != null) ...[
            SizedBox(height: context.space(8)),
            _ShortcutSlot(
              label: 'Alternate',
              child: ShortcutRecorder(
                shortcut: secondaryShortcut,
                onChanged: onSecondaryChanged,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ShortcutSlot extends StatelessWidget {
  const _ShortcutSlot({required this.child, this.label});

  final Widget child;
  final String? label;

  @override
  Widget build(BuildContext context) {
    if (label == null) {
      return child;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          label!,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: ColorTokens.textSecondary(context),
          ),
        ),
        SizedBox(height: context.space(4)),
        child,
      ],
    );
  }
}

class _AccountSection extends StatefulWidget {
  const _AccountSection({
    required this.appState,
    required this.account,
    required this.accent,
    required this.defaultExpanded,
  });

  final AppState appState;
  final EmailAccount account;
  final Color accent;
  final bool defaultExpanded;

  @override
  State<_AccountSection> createState() => _AccountSectionState();
}

class _AccountSectionState extends State<_AccountSection> {
  bool _isTesting = false;
  ConnectionTestReport? _report;
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.defaultExpanded;
  }

  Future<bool> _confirmDeleteAccount(
    BuildContext context,
    EmailAccount account,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: GlassPanel(
            borderRadius: BorderRadius.circular(20),
            padding: const EdgeInsets.all(16),
            variant: GlassVariant.sheet,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Delete account?',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                SizedBox(height: context.space(8)),
                Text(
                  'This removes ${account.displayName} from Tidings. '
                  'Cached mail and settings for this account are deleted.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: ColorTokens.textSecondary(context),
                  ),
                ),
                SizedBox(height: context.space(16)),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).pop(true),
                      icon: const Icon(Icons.delete_outline_rounded),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: BorderSide(
                          color: Colors.redAccent.withValues(alpha: 0.5),
                        ),
                      ),
                      label: const Text('Delete account'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final account = widget.account;
    final appState = widget.appState;
    final accent = widget.accent;
    final checkMinutes = account.imapConfig?.checkMailIntervalMinutes ?? 5;
    final crossFolderEnabled =
        account.imapConfig?.crossFolderThreadingEnabled ?? false;
    final baseAccent = account.accentColorValue == null
        ? accentFromAccount(account.id)
        : Color(account.accentColorValue!);
    final report = _report;
    final reportColor = report == null
        ? null
        : (report.ok ? Colors.greenAccent : Colors.redAccent);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(context.space(14)),
      decoration: BoxDecoration(
        color: ColorTokens.cardFill(context, 0.04),
        borderRadius: BorderRadius.circular(context.radius(18)),
        border: Border.all(color: ColorTokens.border(context, 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(context.radius(12)),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: EdgeInsets.symmetric(
                vertical: context.space(6),
                horizontal: context.space(4),
              ),
              child: Row(
                children: [
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_down_rounded
                        : Icons.keyboard_arrow_right_rounded,
                  ),
                  SizedBox(width: context.space(6)),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.displayName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        account.email,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: ColorTokens.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: _expanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: context.space(8)),
                Row(
                  children: [
                    Text(
                      'Accent',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () =>
                          appState.randomizeAccountAccentColor(account.id),
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Shuffle'),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          horizontal: context.space(8),
                          vertical: context.space(4),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: context.space(8)),
                Wrap(
                  spacing: context.space(12),
                  runSpacing: context.space(8),
                  children: [
                    for (final preset in accentPresets)
                      AccentSwatch(
                        label: preset.label,
                        color: resolveAccent(
                          preset.color,
                          Theme.of(context).brightness,
                        ),
                        selected:
                            preset.color.toARGB32() == baseAccent.toARGB32(),
                        onTap: () => appState.setAccountAccentColor(
                          account.id,
                          preset.color,
                        ),
                      ),
                  ],
                ),
                SizedBox(height: context.space(16)),
                Divider(color: ColorTokens.border(context, 0.12)),
                SizedBox(height: context.space(12)),
                Text(
                  'Connection',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (account.providerType == EmailProviderType.imap) ...[
                  SizedBox(height: context.space(8)),
                  SettingRow(
                    title: 'Check for new mail',
                    subtitle: 'Background refresh interval for Inbox.',
                    trailing: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: checkMinutes,
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          appState.setAccountCheckInterval(
                            accountId: account.id,
                            minutes: value,
                          );
                        },
                        items: const [
                          DropdownMenuItem(value: 1, child: Text('1 min')),
                          DropdownMenuItem(value: 5, child: Text('5 min')),
                          DropdownMenuItem(value: 10, child: Text('10 min')),
                          DropdownMenuItem(value: 15, child: Text('15 min')),
                          DropdownMenuItem(value: 30, child: Text('30 min')),
                          DropdownMenuItem(value: 60, child: Text('60 min')),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: context.space(16)),
                  SettingRow(
                    title: 'Include other folders in threads',
                    subtitle: 'Show messages from folders already fetched.',
                    trailing: AccentSwitch(
                      accent: accent,
                      value: crossFolderEnabled,
                      onChanged: (value) =>
                          appState.setAccountCrossFolderThreading(
                            accountId: account.id,
                            enabled: value,
                          ),
                    ),
                  ),
                ],
                SizedBox(height: context.space(12)),
                Wrap(
                  spacing: context.space(8),
                  runSpacing: context.space(8),
                  children: [
                    if (account.providerType == EmailProviderType.imap)
                      OutlinedButton.icon(
                        onPressed: _isTesting
                            ? null
                            : () async {
                                setState(() {
                                  _isTesting = true;
                                  _report = null;
                                });
                                final result = await appState
                                    .testAccountConnection(account);
                                if (!mounted) {
                                  return;
                                }
                                setState(() {
                                  _isTesting = false;
                                  _report = result;
                                });
                              },
                        icon: _isTesting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.wifi_tethering_rounded),
                        label: Text(
                          _isTesting ? 'Testing...' : 'Test Connection',
                        ),
                      ),
                    if (account.providerType == EmailProviderType.imap)
                      OutlinedButton.icon(
                        onPressed: () => showAccountEditSheet(
                          context,
                          appState: appState,
                          account: account,
                          accent: accent,
                        ),
                        icon: const Icon(Icons.edit_rounded),
                        label: const Text('Edit IMAP/SMTP'),
                      ),
                  ],
                ),
                if (report != null) ...[
                  SizedBox(height: context.space(12)),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(context.space(12)),
                    decoration: BoxDecoration(
                      color: ColorTokens.cardFill(context, 0.06),
                      borderRadius: BorderRadius.circular(context.radius(12)),
                      border: Border.all(
                        color: ColorTokens.border(context, 0.12),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              report.ok ? 'Connection OK' : 'Connection failed',
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(color: reportColor),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () {
                                Clipboard.setData(
                                  ClipboardData(text: report.log),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Log copied.')),
                                );
                              },
                              icon: const Icon(Icons.copy_rounded, size: 18),
                              tooltip: 'Copy log',
                            ),
                          ],
                        ),
                        SizedBox(height: context.space(6)),
                        SelectableText(
                          report.log.trim(),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: reportColor,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
                SizedBox(height: context.space(16)),
                Divider(color: ColorTokens.border(context, 0.12)),
                SizedBox(height: context.space(12)),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final confirmed = await _confirmDeleteAccount(
                        context,
                        account,
                      );
                      if (!confirmed) {
                        return;
                      }
                      await appState.removeAccount(account.id);
                    },
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Delete account'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: BorderSide(
                        color: Colors.redAccent.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

void _showFolderSheet(
  BuildContext context, {
  required Color accent,
  required EmailProvider provider,
  required List<FolderSection> sections,
  required int selectedFolderIndex,
  required ValueChanged<int> onFolderSelected,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _FolderSheet(
      accent: accent,
      provider: provider,
      sections: sections,
      selectedFolderIndex: selectedFolderIndex,
      onFolderSelected: onFolderSelected,
    ),
  );
}
