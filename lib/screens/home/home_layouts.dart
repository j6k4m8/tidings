import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/account_models.dart';
import '../../models/email_models.dart';
import '../../providers/email_provider.dart';
import '../../state/app_state.dart';
import '../../state/tidings_settings.dart';
import '../../widgets/animations/page_reveal.dart';
import '../../widgets/paper_panel.dart';
import '../compose/inline_reply_composer.dart';
import 'home_utils.dart';
import 'thread_detail.dart';
import 'thread_list.dart';
import '../settings/settings_screen.dart';
import 'widgets/home_top_bar.dart';
import 'widgets/refresh_button.dart';
import 'widgets/sidebar_panel.dart';
import 'widgets/sidebar_rail.dart';
import 'widgets/thread_panel_handles.dart';

class WideLayout extends StatelessWidget {
  const WideLayout({
    super.key,
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
    required this.onOutboxTap,
    required this.onRefreshTap,
    required this.outboxCount,
    required this.outboxSelected,
    required this.navIndex,
    required this.onNavSelected,
    required this.onSettingsTap,
    required this.isRefreshing,
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
    this.onReplyFocusChange,
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
  final VoidCallback onOutboxTap;
  final VoidCallback onRefreshTap;
  final int outboxCount;
  final bool outboxSelected;
  final int navIndex;
  final ValueChanged<int> onNavSelected;
  final VoidCallback onSettingsTap;
  final bool isRefreshing;
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
  final ValueChanged<bool>? onReplyFocusChange;

  @override
  Widget build(BuildContext context) {
    final threads = provider.threads;
    final folderSections = provider.folderSections;
    final safeIndex = threads.isEmpty
        ? 0
        : selectedIndex(selectedThreadIndex, threads.length);
    final selectedThread = threads.isEmpty ? null : threads[safeIndex];
    final pinnedFolderItems = pinnedItems(
      folderSections,
      context.tidingsSettings.pinnedFolderPaths,
    );
    final contentPadding = EdgeInsets.fromLTRB(
      context.gutter(16),
      0,
      context.gutter(16),
      context.gutter(16),
    );
    final listOpacity = threadFocused ? 0.6 : 1.0;

    return Column(
      children: [
        HomeTopBar(
          accent: accent,
          searchFocusNode: searchFocusNode,
          onSettingsTap: onSettingsTap,
          onOutboxTap: onOutboxTap,
          onRefreshTap: onRefreshTap,
          isRefreshing: isRefreshing,
          outboxCount: outboxCount,
          outboxSelected: outboxSelected,
        ),
        SizedBox(height: context.space(14)),
        Expanded(
          child: Padding(
            padding: contentPadding,
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
                            child: SidebarRail(
                              account: account,
                              accent: accent,
                              mailboxItems: mailboxItems(folderSections),
                              pinnedItems: pinnedFolderItems,
                              selectedIndex: selectedFolderIndex,
                              onSelected: onFolderSelected,
                              onExpand: onSidebarToggle,
                              onAccountTap: onAccountTap,
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
                                  duration:
                                      const Duration(milliseconds: 180),
                                  child: Listener(
                                    onPointerDown: (_) =>
                                        threadListFocusNode.requestFocus(),
                                    child: Focus(
                                      focusNode: threadListFocusNode,
                                      child: PaperPanel(
                                        borderRadius: BorderRadius.circular(
                                          context.radius(22),
                                        ),
                                        padding: EdgeInsets.all(
                                          context.space(12),
                                        ),
                                        child: ThreadListPanel(
                                          accent: accent,
                                          provider: provider,
                                          selectedIndex: selectedThreadIndex,
                                          onSelected: onThreadSelected,
                                          isCompact: false,
                                          currentUserEmail:
                                              listCurrentUserEmail,
                                          searchFocusNode: searchFocusNode,
                                          showSearch: false,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              IgnorePointer(
                                ignoring: false,
                                child: ThreadPanelHint(
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

                        final availableWidth =
                            constraints.maxWidth - handleWidth;
                        final minListWidth = context.space(280);
                        final minDetailWidth = context.space(260);
                        final snapThreshold = context.space(300);
                        final maxDetailWidth = availableWidth - minListWidth;
                        final boundedMaxDetailWidth =
                            maxDetailWidth < minDetailWidth
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
                          if (!showSettings &&
                              nextDetailWidth <= snapThreshold) {
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
                                duration:
                                    const Duration(milliseconds: 180),
                                child: Listener(
                                  onPointerDown: (_) =>
                                      threadListFocusNode.requestFocus(),
                                  child: Focus(
                                    focusNode: threadListFocusNode,
                                    child: PaperPanel(
                                      borderRadius: BorderRadius.circular(
                                        context.radius(22),
                                      ),
                                      padding: EdgeInsets.all(
                                        context.space(12),
                                      ),
                                      child: ThreadListPanel(
                                        accent: accent,
                                        provider: provider,
                                        selectedIndex: selectedThreadIndex,
                                        onSelected: onThreadSelected,
                                        isCompact: false,
                                        currentUserEmail:
                                            listCurrentUserEmail,
                                        searchFocusNode: searchFocusNode,
                                        showSearch: false,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            ThreadPanelResizeHandle(
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
                                      duration:
                                          const Duration(milliseconds: 300),
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
                                                focusNode:
                                                    threadDetailFocusNode,
                                                onKeyEvent:
                                                    (node, event) =>
                                                        onThreadDetailKeyEvent(
                                                  event,
                                                ),
                                                child: CurrentThreadPanel(
                                                  key: ValueKey(
                                                    selectedThread.id,
                                                  ),
                                                  accent: accent,
                                                  thread: selectedThread,
                                                  provider: provider,
                                                  isCompact: false,
                                                  currentUserEmail:
                                                      detailCurrentUserEmail,
                                                  replyController:
                                                      replyController,
                                                  selectedMessageIndex:
                                                      selectedMessageIndex,
                                                  onMessageSelected:
                                                      onMessageSelected,
                                                  isFocused: threadFocused,
                                                  parentFocusNode:
                                                      threadDetailFocusNode,
                                                  scrollController:
                                                      threadDetailScrollController,
                                                  onReplyFocusChange:
                                                      onReplyFocusChange,
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
          ),
        ),
      ],
    );
  }
}

class CompactLayout extends StatelessWidget {
  const CompactLayout({
    super.key,
    required this.account,
    required this.accent,
    required this.provider,
    required this.selectedThreadIndex,
    required this.onThreadSelected,
    required this.selectedFolderIndex,
    required this.onFolderSelected,
    required this.onAccountTap,
    required this.onCompose,
    required this.onOutboxTap,
    required this.onRefreshTap,
    required this.onSettingsTap,
    required this.outboxCount,
    required this.outboxSelected,
    required this.isRefreshing,
    required this.railOpen,
    required this.onRailToggle,
    required this.railExpanded,
    required this.onRailExpand,
    required this.onRailCollapse,
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
  final VoidCallback onCompose;
  final VoidCallback onOutboxTap;
  final VoidCallback onRefreshTap;
  final VoidCallback onSettingsTap;
  final int outboxCount;
  final bool outboxSelected;
  final bool isRefreshing;
  final bool railOpen;
  final ValueChanged<bool> onRailToggle;
  final bool railExpanded;
  final VoidCallback onRailExpand;
  final VoidCallback onRailCollapse;
  final FocusNode searchFocusNode;
  final FocusNode threadListFocusNode;
  final String listCurrentUserEmail;
  final String Function(EmailThread thread) currentUserEmailForThread;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final isMac = defaultTargetPlatform == TargetPlatform.macOS;
    final topPadding =
        topInset + context.space(isMac ? 22 : 6);
    final pinnedFolderItems = pinnedItems(
      provider.folderSections,
      context.tidingsSettings.pinnedFolderPaths,
    );
    final railWidth = context.space(72);
    final panelWidth = context.space(260);

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            context.gutter(16),
            topPadding,
            context.gutter(16),
            context.space(8),
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Folders',
                onPressed: () {
                  if (railOpen) {
                    onRailToggle(false);
                  } else {
                    onRailCollapse();
                  }
                },
                icon: const Icon(Icons.menu_rounded),
              ),
              SizedBox(width: context.space(8)),
              Expanded(
                child: ThreadSearchRow(
                  accent: accent,
                  focusNode: searchFocusNode,
                ),
              ),
              SizedBox(width: context.space(8)),
              _CompactOutboxButton(
                count: outboxCount,
                accent: accent,
                selected: outboxSelected,
                onTap: onOutboxTap,
              ),
              RefreshIconButton(
                isRefreshing: isRefreshing,
                onPressed: onRefreshTap,
              ),
              IconButton(
                tooltip: 'Settings',
                onPressed: onSettingsTap,
                icon: const Icon(Icons.settings_rounded),
              ),
            ],
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  context.gutter(16),
                  0,
                  context.gutter(16),
                  0,
                ),
                child: PageReveal(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Listener(
                          onPointerDown: (_) =>
                              threadListFocusNode.requestFocus(),
                          child: Focus(
                            focusNode: threadListFocusNode,
                            child: ThreadListPanel(
                              accent: accent,
                              provider: provider,
                              selectedIndex: selectedThreadIndex,
                              onSelected: (index) {
                                onThreadSelected(index);
                                final thread = provider.threads[index];
                                final currentUserEmail =
                                    currentUserEmailForThread(thread);
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
              if (railOpen)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onRailToggle(false),
                    child: const SizedBox.expand(),
                  ),
                ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                top: 0,
                bottom: 0,
                left: railOpen
                    ? context.space(8)
                    : -(railExpanded ? panelWidth : railWidth) -
                        context.space(16),
                child: SizedBox(
                  width: railExpanded ? panelWidth : railWidth,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 160),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: railExpanded
                        ? SidebarPanel(
                            key: const ValueKey('compact-panel'),
                            account: account,
                            accent: accent,
                            provider: provider,
                            sections: provider.folderSections,
                            selectedIndex: selectedFolderIndex,
                            onSelected: (index) {
                              onFolderSelected(index);
                              onRailToggle(false);
                            },
                            onSettingsTap: onSettingsTap,
                            onCollapse: onRailCollapse,
                            onAccountTap: onAccountTap,
                            onCompose: onCompose,
                          )
                        : SidebarRail(
                            key: const ValueKey('compact-rail'),
                            account: account,
                            accent: accent,
                            mailboxItems: mailboxItems(provider.folderSections),
                            pinnedItems: pinnedFolderItems,
                            selectedIndex: selectedFolderIndex,
                            onSelected: (index) {
                              onFolderSelected(index);
                              onRailToggle(false);
                            },
                            onExpand: onRailExpand,
                            onAccountTap: onAccountTap,
                            onCompose: onCompose,
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CompactOutboxButton extends StatelessWidget {
  const _CompactOutboxButton({
    required this.count,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final int count;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : count.toString();
    final badgeVisible = count > 0;
    final iconColor = selected ? accent.withValues(alpha: 0.9) : null;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: badgeVisible ? 'Outbox ($label)' : 'Outbox',
          onPressed: onTap,
          icon: Icon(Icons.outbox_rounded, color: iconColor),
        ),
        if (badgeVisible)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ),
      ],
    );
  }
}
