import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/email_models.dart';
import '../../providers/email_provider.dart';
import '../../providers/unified_email_provider.dart';
import '../../state/tidings_settings.dart';
import '../../utils/email_time.dart';
import '../../theme/account_accent.dart';
import 'home_utils.dart';
import '../../theme/color_tokens.dart';
import '../../widgets/animations/staggered_fade_in.dart';
import 'provider_body.dart';

class ThreadSearchRow extends StatefulWidget {
  const ThreadSearchRow({
    super.key,
    required this.accent,
    this.focusNode,
  });

  final Color accent;
  final FocusNode? focusNode;

  @override
  State<ThreadSearchRow> createState() => _ThreadSearchRowState();
}

class _ThreadSearchRowState extends State<ThreadSearchRow> {
  late FocusNode _focusNode;
  late bool _ownsFocusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode(debugLabel: 'ThreadSearch');
    _ownsFocusNode = widget.focusNode == null;
  }

  @override
  void didUpdateWidget(covariant ThreadSearchRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      if (_ownsFocusNode) {
        _focusNode.dispose();
      }
      _focusNode = widget.focusNode ?? FocusNode(debugLabel: 'ThreadSearch');
      _ownsFocusNode = widget.focusNode == null;
    }
  }

  @override
  void dispose() {
    if (_ownsFocusNode) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderRadius = BorderRadius.circular(context.radius(18));
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);
    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.escape): const _EscapeIntent(),
      },
      child: Actions(
        actions: {
          _EscapeIntent: CallbackAction<_EscapeIntent>(
            onInvoke: (intent) {
              _focusNode.unfocus();
              return null;
            },
          ),
        },
        child: TextField(
          focusNode: _focusNode,
          decoration: InputDecoration(
            hintText: 'Search threads, people, or labels',
            prefixIcon: const Icon(Icons.search_rounded),
            isDense: true,
            filled: true,
            fillColor: isDark
                ? ColorTokens.cardFill(context, 0.14)
                : ColorTokens.cardFillStrong(context, 0.2),
            contentPadding: EdgeInsets.symmetric(
              vertical: context.space(10),
              horizontal: context.space(12),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: borderRadius,
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: borderRadius,
              borderSide:
                  BorderSide(color: widget.accent.withValues(alpha: 0.4), width: 1.2),
            ),
          ),
        ),
      ),
    );
  }
}

class _EscapeIntent extends Intent {
  const _EscapeIntent();
}

class ThreadListPanel extends StatelessWidget {
  const ThreadListPanel({
    super.key,
    required this.accent,
    required this.provider,
    required this.selectedIndex,
    required this.onSelected,
    required this.isCompact,
    required this.currentUserEmail,
    this.searchFocusNode,
    this.showSearch = true,
  });

  final Color accent;
  final EmailProvider provider;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool isCompact;
  final String currentUserEmail;
  final FocusNode? searchFocusNode;
  final bool showSearch;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: provider,
      builder: (context, _) {
        final status = provider.status;
        final threads = provider.threads;
        final entries = _buildThreadEntries(threads);
        final tintByAccount =
            context.tidingsSettings.tintThreadListByAccountAccent;
        final showAccountPill = context.tidingsSettings.showThreadAccountPill;

        Color? tintForThread(EmailThread thread) {
          if (!tintByAccount) {
            return null;
          }
          var tint = accent;
          if (provider is UnifiedEmailProvider) {
            final account =
                (provider as UnifiedEmailProvider).accountForThread(thread.id);
            if (account != null) {
              final baseAccent = account.accentColorValue == null
                  ? accentFromAccount(account.id)
                  : Color(account.accentColorValue!);
              tint = resolveAccent(
                baseAccent,
                Theme.of(context).brightness,
              );
            }
          }
          return tint;
        }

        ThreadAccountInfo? accountInfoForThread(EmailThread thread) {
          if (!showAccountPill || provider is! UnifiedEmailProvider) {
            return null;
          }
          final account =
              (provider as UnifiedEmailProvider).accountForThread(thread.id);
          if (account == null) {
            return null;
          }
          final label = account.displayName.trim().isNotEmpty
              ? account.displayName
              : account.email;
          final baseAccent = account.accentColorValue == null
              ? accentFromAccount(account.id)
              : Color(account.accentColorValue!);
          final resolved = resolveAccent(
            baseAccent,
            Theme.of(context).brightness,
          );
          return ThreadAccountInfo(
            label: label,
            email: account.email,
            accent: resolved,
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isCompact) ...[
              Row(
                children: [
                  Text(
                    folderLabelForPath(
                          provider.folderSections,
                          provider.selectedFolderPath,
                        ) ??
                        'Inbox',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                ],
              ),
              if (showSearch) ...[
                SizedBox(height: context.space(12)),
                ThreadSearchRow(accent: accent, focusNode: searchFocusNode),
                SizedBox(height: context.space(12)),
              ],
              SizedBox(height: context.space(8)),
            ],
            Expanded(
              child: ProviderBody(
                status: status,
                errorMessage: provider.errorMessage,
                onRetry: provider.refresh,
                isEmpty: threads.isEmpty,
                emptyMessage: 'No messages yet.',
                child: ListView.builder(
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    if (entry.header != null) {
                      return _ThreadSectionHeader(label: entry.header!);
                    }
                    final thread = entry.thread!;
                    final selected = entry.index == selectedIndex;
                    final latestMessage =
                        provider.latestMessageForThread(thread.id);
                    final participants = _filterParticipants(
                      thread.participants,
                      currentUserEmail,
                      context.tidingsSettings.hideSelfInThreadList,
                    );
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        StaggeredFadeIn(
                          index: entry.index ?? 0,
                          child: ThreadTile(
                            thread: thread,
                            participants: participants,
                            latestMessage: latestMessage,
                            accent: accent,
                            backgroundTint: tintForThread(thread),
                            accountInfo: accountInfoForThread(thread),
                            selected: selected,
                            onTap: () => onSelected(entry.index ?? 0),
                          ),
                        ),
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: ColorTokens.border(context, 0.08),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class ThreadTile extends StatefulWidget {
  const ThreadTile({
    super.key,
    required this.thread,
    required this.participants,
    required this.latestMessage,
    required this.accent,
    this.backgroundTint,
    this.accountInfo,
    required this.selected,
    required this.onTap,
  });

  final EmailThread thread;
  final List<EmailAddress> participants;
  final EmailMessage? latestMessage;
  final Color accent;
  final Color? backgroundTint;
  final ThreadAccountInfo? accountInfo;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<ThreadTile> createState() => _ThreadTileState();
}

class _ThreadTileState extends State<ThreadTile> {
  bool _hovered = false;
  bool _pressed = false;

  void _setHovered(bool value) {
    if (_hovered == value) {
      return;
    }
    setState(() => _hovered = value);
  }

  void _setPressed(bool value) {
    if (_pressed == value) {
      return;
    }
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = accentTokensFor(context, widget.accent);
    final subject = widget.thread.subject;
    final latestMessage = widget.latestMessage;
    final isUnread = widget.thread.unread || (latestMessage?.isUnread ?? false);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tintFill = widget.backgroundTint == null
        ? Colors.transparent
        : widget.backgroundTint!.withValues(alpha: isDark ? 0.06 : 0.04);
    final baseFill = widget.selected
        ? widget.accent.withValues(alpha: 0.12)
        : tintFill;
    final hoverOverlay = isDark
        ? Colors.white.withValues(alpha: _pressed ? 0.1 : 0.06)
        : Colors.black.withValues(alpha: _pressed ? 0.08 : 0.04);
    final fill = _hovered || _pressed
        ? Color.alphaBlend(hoverOverlay, baseFill)
        : baseFill;
    final baseParticipantStyle =
        Theme.of(context).textTheme.labelMedium?.copyWith(
              color: widget.selected
                  ? scheme.onSurface.withValues(alpha: 0.85)
                  : scheme.onSurface.withValues(
                      alpha: isUnread ? 0.7 : 0.55,
                    ),
              fontWeight: FontWeight.w500,
            );
    final latestSender = latestMessage?.from.email;
    final highlightParticipantStyle = baseParticipantStyle?.copyWith(
      color: widget.selected
          ? scheme.onSurface
          : (isUnread
              ? tokens.onSurface
              : scheme.onSurface.withValues(alpha: 0.85)),
      fontWeight: FontWeight.w600,
    );
    final settings = context.tidingsSettings;
    final ts = widget.thread.receivedAt ?? latestMessage?.receivedAt;
    final displayTime = ts != null
        ? formatEmailTime(
            ts,
            dateOrder: settings.dateOrder,
            use24h: settings.use24HourTime,
          )
        : widget.thread.time;
    final participants = _orderedParticipants(
      widget.participants,
      latestSender,
    );
    final accountInfo = widget.accountInfo;
    final accountAccent = accountInfo?.accent ?? widget.accent;
    final accountTokens = accentTokensFor(context, accountAccent);
    final snippet = latestMessage?.bodyPlainText ?? '';
    final subjectSnippet = subject.isEmpty
        ? snippet
        : snippet.isEmpty
            ? subject
            : '$subject — $snippet';
    const previewLines = 2;

    return MouseRegion(
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => _setPressed(true),
        onTapCancel: () => _setPressed(false),
        onTapUp: (_) => _setPressed(false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(
            vertical: context.space(10),
            horizontal: context.space(12),
          ),
          decoration: BoxDecoration(color: fill),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: context.space(52)),
            child: Stack(
              children: [
                if (widget.selected)
                  Positioned(
                    left: 0,
                    top: context.space(6),
                    bottom: context.space(6),
                    child: Container(
                      width: 3,
                      decoration: BoxDecoration(
                        color: widget.accent,
                        borderRadius: BorderRadius.circular(context.radius(6)),
                      ),
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.only(
                    left: widget.selected ? context.space(6) : 0,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SenderStack(participants: participants),
                      SizedBox(width: context.space(12)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (isUnread)
                                  Container(
                                    width: context.space(6),
                                    height: context.space(6),
                                    margin:
                                        EdgeInsets.only(right: context.space(6)),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: widget.accent,
                                    ),
                                  )
                                else
                                  const SizedBox.shrink(),
                                Expanded(
                                  child: RichText(
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    text: TextSpan(
                                      children: [
                                        for (var i = 0;
                                            i < widget.participants.length;
                                            i++)
                                          TextSpan(
                                            text: widget.participants[i]
                                                    .normalizedDisplayName +
                                                (i ==
                                                        widget.participants
                                                                .length -
                                                            1
                                                    ? ''
                                                    : ', '),
                                            style: widget.participants[i]
                                                        .email ==
                                                    latestSender
                                                ? highlightParticipantStyle
                                                : baseParticipantStyle,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(width: context.space(8)),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (widget.thread.starred) ...[
                                      Icon(
                                        Icons.star_rounded,
                                        color: widget.accent,
                                        size: 16,
                                      ),
                                      SizedBox(width: context.space(4)),
                                    ],
                                    if (accountInfo != null) ...[
                                      Tooltip(
                                        message: accountInfo.email,
                                        child: Container(
                                          constraints: BoxConstraints(
                                            maxWidth: context.space(120),
                                          ),
                                          padding: EdgeInsets.symmetric(
                                            horizontal: context.space(6),
                                            vertical: context.space(2),
                                          ),
                                          decoration: BoxDecoration(
                                            color: accountAccent.withValues(
                                              alpha: isDark ? 0.16 : 0.12,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              context.radius(999),
                                            ),
                                            border: Border.all(
                                              color: accountAccent.withValues(
                                                alpha: isDark ? 0.28 : 0.22,
                                              ),
                                            ),
                                          ),
                                          child: Text(
                                            accountInfo.label,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelSmall
                                                ?.copyWith(
                                                  color:
                                                      accountTokens.onSurface,
                                                  letterSpacing: -0.2,
                                                ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: context.space(6)),
                                    ],
                                    Text(
                                      displayTime,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      softWrap: false,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: scheme.onSurface.withValues(
                                              alpha: 0.55,
                                            ),
                                            letterSpacing: -0.3,
                                          ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            SizedBox(height: context.space(4)),
                            Text(
                              subjectSnippet,
                              maxLines: previewLines,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    fontWeight: widget.thread.unread
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    color: widget.selected
                                        ? scheme.onSurface
                                        : scheme.onSurface.withValues(
                                            alpha: isUnread ? 0.82 : 0.6,
                                          ),
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SenderStack extends StatelessWidget {
  const _SenderStack({required this.participants});

  final List<EmailAddress> participants;

  @override
  Widget build(BuildContext context) {
    final visible = participants.take(4).toList();
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : context.space(72);
        final count = visible.length.clamp(1, 4);
        final maxCircle = context.space(40);
        final minCircle = context.space(30);
        final circleSize = (maxHeight / count).clamp(minCircle, maxCircle);
        final spacing =
            count == 1 ? 0 : (maxHeight - circleSize) / (count - 1);
        final width = circleSize + 6;
        return SizedBox(
          width: width,
          height: maxHeight,
          child: Stack(
            children: [
              for (var i = 0; i < visible.length; i++)
                Positioned(
                  top: (i * spacing).toDouble(),
                  child: Container(
                    width: circleSize,
                    height: circleSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: scheme.surface,
                      border: Border.all(
                        color: ColorTokens.border(context, 0.2),
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        visible[i].initial,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class ThreadAccountInfo {
  const ThreadAccountInfo({
    required this.label,
    required this.email,
    required this.accent,
  });

  final String label;
  final String email;
  final Color accent;
}

List<EmailAddress> _orderedParticipants(
  List<EmailAddress> participants,
  String? latestSender,
) {
  if (latestSender == null) {
    return participants;
  }
  final index =
      participants.indexWhere((participant) => participant.email == latestSender);
  if (index <= 0) {
    return participants;
  }
  final ordered = List<EmailAddress>.from(participants);
  final sender = ordered.removeAt(index);
  ordered.insert(0, sender);
  return ordered;
}

List<EmailAddress> _filterParticipants(
  List<EmailAddress> participants,
  String currentUserEmail,
  bool hideSelf,
) {
  if (!hideSelf) {
    return participants;
  }
  final filtered = participants
      .where((participant) => participant.email != currentUserEmail)
      .toList();
  return filtered.isEmpty ? participants : filtered;
}


class _ThreadListEntry {
  const _ThreadListEntry.header(this.header)
      : thread = null,
        index = null;
  const _ThreadListEntry.thread(this.thread, this.index) : header = null;

  final String? header;
  final EmailThread? thread;
  final int? index;
}

List<_ThreadListEntry> _buildThreadEntries(List<EmailThread> threads) {
  final entries = <_ThreadListEntry>[];
  String? currentHeader;
  for (var i = 0; i < threads.length; i++) {
    final thread = threads[i];
    final label = _sectionLabel(thread.receivedAt);
    if (label != currentHeader) {
      currentHeader = label;
      entries.add(_ThreadListEntry.header(label));
    }
    entries.add(_ThreadListEntry.thread(thread, i));
  }
  return entries;
}

String _sectionLabel(DateTime? timestamp) {
  if (timestamp == null) {
    return 'Earlier';
  }
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final date = DateTime(timestamp.year, timestamp.month, timestamp.day);
  if (date == today) {
    return 'Today';
  }
  if (date == today.subtract(const Duration(days: 1))) {
    return 'Yesterday';
  }
  return 'Earlier';
}

class _ThreadSectionHeader extends StatelessWidget {
  const _ThreadSectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: ColorTokens.textSecondary(context, 0.6),
          letterSpacing: 0.6,
        );
    return Padding(
      padding: EdgeInsets.only(
        top: context.space(12),
        bottom: context.space(6),
        left: context.space(6),
      ),
      child: Row(
        children: [
          Text(label.toUpperCase(), style: style),
          SizedBox(width: context.space(10)),
          Expanded(
            child: Divider(
              color: ColorTokens.border(context, 0.08),
              thickness: 1,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}
