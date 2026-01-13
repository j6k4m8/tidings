import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/account_models.dart';
import '../models/folder_models.dart';
import '../providers/email_provider.dart';
import '../state/app_state.dart';
import '../state/tidings_settings.dart';
import '../theme/color_tokens.dart';
import '../theme/glass.dart';
import '../theme/account_accent.dart';
import '../theme/theme_palette.dart';
import '../widgets/tidings_background.dart';
import 'compose/compose_sheet.dart';
import 'home/thread_detail.dart';
import 'home/thread_list.dart';
import 'onboarding_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.appState,
    required this.accent,
  });

  final AppState appState;
  final Color accent;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _threadPanelFractionKey = 'threadPanelFraction';
  int _selectedThreadIndex = 0;
  int _selectedFolderIndex = 0;
  int _navIndex = 0;
  bool _showSettings = false;
  bool _sidebarCollapsed = false;
  double _threadPanelFraction = 0.58;
  bool _threadPanelOpen = true;
  SharedPreferences? _prefs;
  String? _lastAccountId;

  @override
  void initState() {
    super.initState();
    _loadThreadPanelPrefs();
    _lastAccountId = widget.appState.selectedAccount?.id;
    widget.appState.addListener(_handleAppStateChange);
  }

  Future<void> _loadThreadPanelPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getDouble(_threadPanelFractionKey);
      if (!mounted) {
        return;
      }
      _prefs = prefs;
      if (stored != null) {
        setState(() {
          _threadPanelFraction = stored.clamp(0.3, 0.8);
        });
      }
    } on PlatformException {
      // SharedPreferences plugin can be unavailable during hot reload.
    }
  }

  void _persistThreadPanelFraction(double value) {
    _prefs?.setDouble(_threadPanelFractionKey, value);
  }

  @override
  void dispose() {
    widget.appState.removeListener(_handleAppStateChange);
    super.dispose();
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
      _lastAccountId = currentId;
    }
  }

  void _handleFolderSelected(EmailProvider provider, int index) {
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

  @override
  Widget build(BuildContext context) {
    final account = widget.appState.selectedAccount;
    final provider = widget.appState.currentProvider;
    if (account == null || provider == null) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1024;
        final showSettings = _showSettings;
        final effectiveFolderIndex = _folderIndexForPath(
              provider.folderSections,
              provider.selectedFolderPath,
            ) ??
            _selectedFolderIndex;

        return Scaffold(
          extendBody: true,
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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
                      provider: provider,
                      selectedThreadIndex: _selectedThreadIndex,
                      onThreadSelected: (index) => setState(() {
                        _selectedThreadIndex = index;
                        _threadPanelOpen = true;
                      }),
                      selectedFolderIndex: effectiveFolderIndex,
                      onFolderSelected: (index) =>
                          _handleFolderSelected(provider, index),
                      sidebarCollapsed: _sidebarCollapsed,
                      onSidebarToggle: () => setState(() {
                        _sidebarCollapsed = !_sidebarCollapsed;
                      }),
                      onAccountTap: () => showAccountPickerSheet(
                        context,
                        appState: widget.appState,
                        accent: widget.accent,
                      ),
                      navIndex: _navIndex,
                      onNavSelected: (index) => setState(() {
                        _navIndex = index;
                        _showSettings = false;
                      }),
                      onSettingsTap: () => setState(() => _showSettings = true),
                      onSettingsClose: () =>
                          setState(() => _showSettings = false),
                      showSettings: showSettings,
                      threadPanelFraction: _threadPanelFraction,
                      threadPanelOpen: _threadPanelOpen,
                      onThreadPanelResize: (fraction) {
                        setState(() => _threadPanelFraction = fraction);
                        _persistThreadPanelFraction(fraction);
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
                      provider: provider,
                      selectedThreadIndex: _selectedThreadIndex,
                      onThreadSelected: (index) => setState(() {
                        _selectedThreadIndex = index;
                        _threadPanelOpen = true;
                      }),
                      selectedFolderIndex: effectiveFolderIndex,
                      onFolderSelected: (index) =>
                          _handleFolderSelected(provider, index),
                      onAccountTap: () => showAccountPickerSheet(
                        context,
                        appState: widget.appState,
                        accent: widget.accent,
                      ),
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
    required this.threadPanelFraction,
    required this.threadPanelOpen,
    required this.onThreadPanelResize,
    required this.onThreadPanelOpen,
    required this.onThreadPanelClose,
    required this.onCompose,
  });

  final AppState appState;
  final EmailAccount account;
  final Color accent;
  final EmailProvider provider;
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
  final double threadPanelFraction;
  final bool threadPanelOpen;
  final ValueChanged<double> onThreadPanelResize;
  final VoidCallback onThreadPanelOpen;
  final VoidCallback onThreadPanelClose;
  final VoidCallback onCompose;

  @override
  Widget build(BuildContext context) {
    final threads = provider.threads;
    final folderSections = provider.folderSections;
    final safeIndex = threads.isEmpty
        ? 0
        : _selectedIndex(selectedThreadIndex, threads.length);
    final selectedThread = threads.isEmpty ? null : threads[safeIndex];
    final padding = EdgeInsets.all(context.gutter(16));

    return Padding(
      padding: padding,
      child: PageReveal(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            sidebarCollapsed
                ? SizedBox(
                    width: context.space(72),
                    child: _SidebarRail(
                      account: account,
                      accent: accent,
                      mailboxItems: _mailboxItems(folderSections),
                      selectedIndex: selectedFolderIndex,
                      onSelected: onFolderSelected,
                      onExpand: onSidebarToggle,
                      onAccountTap: onAccountTap,
                      onSettingsTap: onSettingsTap,
                    ),
                  )
                : SizedBox(
                    width: context.space(240),
                    child: SidebarPanel(
                      account: account,
                      accent: accent,
                      sections: folderSections,
                      selectedIndex: selectedFolderIndex,
                      onSelected: onFolderSelected,
                      onSettingsTap: onSettingsTap,
                      onCollapse: onSidebarToggle,
                      onAccountTap: onAccountTap,
                      onCompose: onCompose,
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
                          child: ThreadListPanel(
                            accent: accent,
                            provider: provider,
                            selectedIndex: selectedThreadIndex,
                            onSelected: onThreadSelected,
                            isCompact: false,
                            currentUserEmail: account.email,
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
                        child: ThreadListPanel(
                          accent: accent,
                          provider: provider,
                          selectedIndex: selectedThreadIndex,
                          onSelected: onThreadSelected,
                          isCompact: false,
                          currentUserEmail: account.email,
                        ),
                      ),
                      _ResizeHandle(onDragUpdate: handleResize),
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
                                    : CurrentThreadPanel(
                                        key: ValueKey(selectedThread.id),
                                        accent: accent,
                                        thread: selectedThread,
                                        provider: provider,
                                        isCompact: false,
                                        currentUserEmail: account.email,
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

const List<FolderItem> _fallbackRailItems = [
  FolderItem(
    index: 0,
    name: 'Inbox',
    path: 'INBOX',
    icon: Icons.inbox_rounded,
  ),
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
  FolderItem(
    index: 3,
    name: 'Sent',
    path: 'Sent',
    icon: Icons.send_rounded,
  ),
];

class _ResizeHandle extends StatelessWidget {
  const _ResizeHandle({required this.onDragUpdate});

  final ValueChanged<double> onDragUpdate;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: (details) => onDragUpdate(details.delta.dx),
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
  });

  final Color accent;
  final double width;
  final VoidCallback onTap;
  final ValueChanged<double> onDragUpdate;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: onTap,
        onHorizontalDragUpdate: (details) => onDragUpdate(details.delta.dx),
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
  });

  final EmailAccount account;
  final Color accent;
  final EmailProvider provider;
  final int selectedThreadIndex;
  final ValueChanged<int> onThreadSelected;
  final int selectedFolderIndex;
  final ValueChanged<int> onFolderSelected;
  final VoidCallback onAccountTap;

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
                  sections: provider.folderSections,
                  selectedFolderIndex: selectedFolderIndex,
                  onFolderSelected: onFolderSelected,
                  onAccountTap: onAccountTap,
                ),
                SizedBox(height: context.space(16)),
                ThreadSearchRow(accent: accent),
                SizedBox(height: context.space(16)),
                ThreadQuickChips(accent: accent),
                SizedBox(height: context.space(16)),
                Expanded(
                  child: ThreadListPanel(
                    accent: accent,
                    provider: provider,
                    selectedIndex: selectedThreadIndex,
                    onSelected: (index) {
                      onThreadSelected(index);
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ThreadScreen(
                            accent: accent,
                            thread: provider.threads[index],
                            provider: provider,
                            currentUserEmail: account.email,
                          ),
                        ),
                      );
                    },
                    isCompact: true,
                    currentUserEmail: account.email,
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
                      Container(
                        padding: EdgeInsets.all(context.space(4)),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: accent, width: 2),
                        ),
                        child: CircleAvatar(
                          radius: context.space(18),
                          backgroundColor: accent.withValues(alpha: 0.2),
                          child: Text(
                            account.displayName.substring(0, 1).toUpperCase(),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
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
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: ColorTokens.textSecondary(context),
                                  ),
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
              OutlinedButton.icon(
                onPressed: onCompose,
                icon: const Icon(Icons.edit_rounded, size: 16),
                label: const Text('Compose'),
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
    required this.sections,
    required this.selectedIndex,
    required this.onSelected,
  });

  final Color accent;
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
    required this.sections,
    required this.selectedFolderIndex,
    required this.onFolderSelected,
  });

  final Color accent;
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
    required this.selectedIndex,
    required this.onSelected,
  });

  final FolderSection section;
  final Color accent;
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
              selected: item.index == selectedIndex,
              onTap: () => onSelected(item.index),
            );
          }),
        ],
      ),
    );
  }
}

class _FolderRow extends StatelessWidget {
  const _FolderRow({
    required this.item,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final FolderItem item;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unread = item.unreadCount > 0;
    final showUnreadCounts =
        context.tidingsSettings.showFolderUnreadCounts;
    final baseColor = Theme.of(context).colorScheme.onSurface;
    final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: unread ? baseColor : baseColor.withValues(alpha: 0.65),
          fontWeight: unread ? FontWeight.w600 : FontWeight.w500,
        );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: context.space(6)),
        padding: EdgeInsets.fromLTRB(
          context.space(6) + item.depth * context.space(12),
          context.space(7),
          context.space(6),
          context.space(7),
        ),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.14) : Colors.transparent,
          borderRadius: BorderRadius.circular(context.radius(12)),
        ),
        child: Row(
          children: [
            if (selected)
              Container(
                width: 2,
                height: context.space(16),
                margin: EdgeInsets.only(right: context.space(8)),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(context.radius(8)),
                ),
              )
            else
              SizedBox(width: context.space(10)),
            if (item.icon != null) ...[
              Icon(
                item.icon,
                size: 16,
                color: unread
                    ? baseColor.withValues(alpha: 0.8)
                    : baseColor.withValues(alpha: 0.55),
              ),
              SizedBox(width: context.space(8)),
            ],
            Expanded(
              child: Text(
                item.name,
                style: textStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (unread && showUnreadCounts)
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: context.space(6),
                  vertical: context.space(2),
                ),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(context.radius(999)),
                ),
                child: Text(
                  item.unreadCount.toString(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
          ],
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
    required this.selectedIndex,
    required this.onSelected,
    required this.onExpand,
    required this.onAccountTap,
    required this.onSettingsTap,
  });

  final EmailAccount account;
  final Color accent;
  final List<FolderItem> mailboxItems;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onExpand;
  final VoidCallback onAccountTap;
  final VoidCallback onSettingsTap;

  @override
  Widget build(BuildContext context) {
    final items = mailboxItems.isEmpty ? _fallbackRailItems : mailboxItems;
    return GlassPanel(
      borderRadius: BorderRadius.circular(context.radius(22)),
      padding: EdgeInsets.symmetric(
        vertical: context.space(12),
        horizontal: context.space(8),
      ),
      variant: GlassVariant.panel,
      child: Column(
        children: [
          CircleAvatar(
            radius: context.space(18),
            backgroundColor: accent.withValues(alpha: 0.2),
            child: GestureDetector(
              onTap: onAccountTap,
              child: Text(
                account.displayName.substring(0, 1).toUpperCase(),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
          SizedBox(height: context.space(16)),
          for (final item in items.take(4))
            _RailIconButton(
              icon: item.icon ?? Icons.mail_outline_rounded,
              selected: selectedIndex == item.index,
              accent: accent,
              onTap: () => onSelected(item.index),
              label: item.name,
            ),
          const Spacer(),
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
    required this.sections,
    required this.selectedFolderIndex,
    required this.onFolderSelected,
    required this.onAccountTap,
  });

  final EmailAccount account;
  final Color accent;
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
          child: CircleAvatar(
            radius: context.space(18),
            backgroundColor: accent.withValues(alpha: 0.2),
            child: Text(
              account.displayName.substring(0, 1).toUpperCase(),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
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
        length: 5,
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
            const _SettingsTabBar(),
            SizedBox(height: context.space(12)),
            Expanded(
              child: TabBarView(
                children: [
                  _SettingsTab(
                    child: _AppearanceSettings(
                      accent: accent,
                      segmentedStyle: segmentedStyle,
                    ),
                  ),
                  _SettingsTab(
                    child: _LayoutSettings(segmentedStyle: segmentedStyle),
                  ),
                  const _SettingsTab(child: _ThreadsSettings()),
                  _SettingsTab(
                    child: _FoldersSettings(accent: accent),
                  ),
                  _SettingsTab(
                    child: _AccountsSettings(
                      appState: appState,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsTabBar extends StatelessWidget {
  const _SettingsTabBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(context.space(4)),
      decoration: BoxDecoration(
        color: ColorTokens.cardFill(context, 0.1),
        borderRadius: BorderRadius.circular(context.radius(16)),
        border: Border.all(color: ColorTokens.border(context, 0.12)),
      ),
      child: TabBar(
        isScrollable: true,
        labelPadding: EdgeInsets.symmetric(horizontal: context.space(6)),
        labelColor: Theme.of(context).colorScheme.onSurface,
        unselectedLabelColor: ColorTokens.textSecondary(context),
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          color: ColorTokens.cardFill(context, 0.2),
          borderRadius: BorderRadius.circular(context.radius(12)),
        ),
        tabs: const [
          _SettingsTabLabel(text: 'Appearance'),
          _SettingsTabLabel(text: 'Layout'),
          _SettingsTabLabel(text: 'Threads'),
          _SettingsTabLabel(text: 'Folders'),
          _SettingsTabLabel(text: 'Accounts'),
        ],
      ),
    );
  }
}

class _SettingsTabLabel extends StatelessWidget {
  const _SettingsTabLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.space(18),
          vertical: context.space(6),
        ),
        child: Text(text),
      ),
    );
  }
}

class _SettingsTab extends StatelessWidget {
  const _SettingsTab({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: context.space(8)),
      child: child,
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
        _SettingRow(
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
        _SettingRow(
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
        _SettingRow(
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
        _SettingRow(
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
                        child: _CornerRadiusOption(
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
  const _ThreadsSettings();

  @override
  Widget build(BuildContext context) {
    final settings = context.tidingsSettings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Threads', style: Theme.of(context).textTheme.titleLarge),
        SizedBox(height: context.space(12)),
        _SettingRow(
          title: 'Auto-expand unread',
          subtitle: 'Open unread threads to show the latest message.',
          trailing: AccentSwitch(
            accent: Theme.of(context).colorScheme.primary,
            value: settings.autoExpandUnread,
            onChanged: settings.setAutoExpandUnread,
          ),
        ),
        SizedBox(height: context.space(16)),
        _SettingRow(
          title: 'Auto-expand latest',
          subtitle: 'Keep the newest thread expanded in the list.',
          trailing: AccentSwitch(
            accent: Theme.of(context).colorScheme.primary,
            value: settings.autoExpandLatest,
            onChanged: settings.setAutoExpandLatest,
          ),
        ),
        SizedBox(height: context.space(16)),
        _SettingRow(
          title: 'Hide subject lines',
          subtitle: 'Show only the message body in thread view.',
          trailing: AccentSwitch(
            accent: Theme.of(context).colorScheme.primary,
            value: settings.hideThreadSubjects,
            onChanged: settings.setHideThreadSubjects,
          ),
        ),
        SizedBox(height: context.space(16)),
        _SettingRow(
          title: 'Hide yourself in thread list',
          subtitle: 'Remove your address from sender rows.',
          trailing: AccentSwitch(
            accent: Theme.of(context).colorScheme.primary,
            value: settings.hideSelfInThreadList,
            onChanged: settings.setHideSelfInThreadList,
          ),
        ),
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
        _SettingRow(
          title: 'Show labels',
          subtitle: 'Include the Labels section in the sidebar.',
          trailing: AccentSwitch(
            accent: accent,
            value: settings.showFolderLabels,
            onChanged: settings.setShowFolderLabels,
          ),
        ),
        SizedBox(height: context.space(16)),
        _SettingRow(
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
  const _AccountsSettings({
    required this.appState,
  });

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    final account = appState.selectedAccount;
    if (account == null) {
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
    final baseAccent = account.accentColorValue == null
        ? accentFromAccount(account.id)
        : Color(account.accentColorValue!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Accounts', style: Theme.of(context).textTheme.titleLarge),
        SizedBox(height: context.space(12)),
        Text(
          account.email,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        SizedBox(height: context.space(16)),
        Text(
          'Accent color',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        SizedBox(height: context.space(8)),
        Wrap(
          spacing: context.space(12),
          runSpacing: context.space(8),
          children: [
            for (final preset in _accentPresets)
              _AccentSwatch(
                label: preset.label,
                color: resolveAccent(preset.color, Theme.of(context).brightness),
                selected: preset.color.toARGB32() == baseAccent.toARGB32(),
                onTap: () => appState.setAccountAccentColor(
                  account.id,
                  preset.color,
                ),
              ),
          ],
        ),
        SizedBox(height: context.space(12)),
        OutlinedButton.icon(
          onPressed: () => appState.randomizeAccountAccentColor(account.id),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Shuffle'),
        ),
      ],
    );
  }
}

class _AccentPreset {
  const _AccentPreset(this.label, this.color);

  final String label;
  final Color color;
}

const List<_AccentPreset> _accentPresets = [
  _AccentPreset('Indigo', Color(0xFF6F7BFF)),
  _AccentPreset('Mint', Color(0xFF45D6B4)),
  _AccentPreset('Coral', Color(0xFFFF7A59)),
  _AccentPreset('Amber', Color(0xFFFFB347)),
  _AccentPreset('Teal', Color(0xFF35B7C3)),
  _AccentPreset('Rose', Color(0xFFF06292)),
];

class _AccentSwatch extends StatelessWidget {
  const _AccentSwatch({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ringColor =
        selected ? Theme.of(context).colorScheme.primary : Colors.transparent;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: context.space(22),
              height: context.space(22),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                border: Border.all(
                  color: ringColor,
                  width: 2,
                ),
              ),
            ),
            SizedBox(width: context.space(8)),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 520;
        final textBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.bodyLarge),
            SizedBox(height: context.space(4)),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: ColorTokens.textSecondary(context),
              ),
            ),
          ],
        );
        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              textBlock,
              SizedBox(height: context.space(12)),
              trailing,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: textBlock),
            SizedBox(width: context.space(16)),
            trailing,
          ],
        );
      },
    );
  }
}

class AccentSwitch extends StatelessWidget {
  const AccentSwitch({
    super.key,
    required this.accent,
    required this.value,
    required this.onChanged,
  });

  final Color accent;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = accentTokensFor(context, accent);
    return Switch.adaptive(
      value: value,
      onChanged: onChanged,
      activeThumbColor: tokens.base,
      activeTrackColor: tokens.track,
      inactiveTrackColor: ColorTokens.cardFill(context, 0.2),
    );
  }
}

class _CornerRadiusOption extends StatelessWidget {
  const _CornerRadiusOption({
    required this.label,
    required this.radius,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final double radius;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? Theme.of(context).colorScheme.primary
        : ColorTokens.border(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: context.space(52),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(radius),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: selected ? Theme.of(context).colorScheme.primary : null,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class PageReveal extends StatelessWidget {
  const PageReveal({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - value)),
            child: child,
          ),
        );
      },
    );
  }
}

class GlassActionButton extends StatelessWidget {
  const GlassActionButton({
    super.key,
    required this.accent,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final Color accent;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = accentTokensFor(context, accent);
    return GestureDetector(
      onTap: onTap,
      child: GlassPanel(
        borderRadius: BorderRadius.circular(context.radius(24)),
        padding: EdgeInsets.symmetric(
          horizontal: context.space(16),
          vertical: context.space(12),
        ),
        variant: GlassVariant.action,
        accent: tokens.base,
        selected: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: tokens.onSurface),
            SizedBox(width: context.space(8)),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: tokens.onSurface),
            ),
          ],
        ),
      ),
    );
  }
}

class GlassBottomNav extends StatelessWidget {
  const GlassBottomNav({
    super.key,
    required this.accent,
    required this.currentIndex,
    required this.onTap,
  });

  final Color accent;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = accentTokensFor(context, accent);
    final items = const [
      _NavItem(icon: Icons.inbox_rounded, label: 'Inbox'),
      _NavItem(icon: Icons.bolt_rounded, label: 'Focus'),
      _NavItem(icon: Icons.search_rounded, label: 'Search'),
      _NavItem(icon: Icons.settings_rounded, label: 'Settings'),
    ];

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          context.gutter(16),
          0,
          context.gutter(16),
          context.space(16),
        ),
        child: GlassPanel(
          borderRadius: BorderRadius.circular(context.radius(26)),
          padding: EdgeInsets.symmetric(
            horizontal: context.space(8),
            vertical: context.space(10),
          ),
          variant: GlassVariant.nav,
          child: Row(
            children: List.generate(items.length, (index) {
              final item = items[index];
              final selected = index == currentIndex;
              final textColor = selected
                  ? tokens.onSurface
                  : ColorTokens.textSecondary(context, 0.6);

              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: EdgeInsets.symmetric(vertical: context.space(8)),
                    decoration: BoxDecoration(
                      color: selected
                          ? tokens.base.withValues(alpha: 0.18)
                          : null,
                      borderRadius: BorderRadius.circular(context.radius(18)),
                      border: Border.all(
                        color: selected
                            ? tokens.base.withValues(alpha: 0.5)
                            : Colors.transparent,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(item.icon, color: textColor, size: 20),
                        SizedBox(height: context.space(4)),
                        Text(
                          item.label,
                          style: Theme.of(
                            context,
                          ).textTheme.labelLarge?.copyWith(color: textColor),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

void _showFolderSheet(
  BuildContext context, {
  required Color accent,
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
      sections: sections,
      selectedFolderIndex: selectedFolderIndex,
      onFolderSelected: onFolderSelected,
    ),
  );
}
