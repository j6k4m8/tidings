import 'package:flutter/material.dart';

import '../../models/email_models.dart';
import '../../providers/email_provider.dart';
import '../../state/tidings_settings.dart';
import '../../theme/account_accent.dart';
import '../../theme/color_tokens.dart';
import '../../theme/glass.dart';
import '../../widgets/animations/staggered_fade_in.dart';
import '../../widgets/glass/glass_pill.dart';
import 'provider_body.dart';

class ThreadSearchRow extends StatelessWidget {
  const ThreadSearchRow({super.key, required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderRadius = BorderRadius.circular(context.radius(18));
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.16)
        : Colors.black.withValues(alpha: 0.12);
    return TextField(
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
              BorderSide(color: accent.withValues(alpha: 0.6), width: 1.2),
        ),
      ),
    );
  }
}

class ThreadQuickChips extends StatelessWidget {
  const ThreadQuickChips({super.key, required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: context.space(8),
      runSpacing: context.space(8),
      children: [
        GlassPill(label: 'Unread', accent: accent, selected: true, dense: true),
        const GlassPill(label: 'Pinned', dense: true),
        const GlassPill(label: 'Follow up', dense: true),
        const GlassPill(label: 'Snoozed', dense: true),
      ],
    );
  }
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
  });

  final Color accent;
  final EmailProvider provider;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool isCompact;
  final String currentUserEmail;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: provider,
      builder: (context, _) {
        final status = provider.status;
        final threads = provider.threads;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isCompact) ...[
              Row(
                children: [
                  Text('Inbox', style: Theme.of(context).textTheme.displaySmall),
                  const Spacer(),
                  GlassPill(label: 'Focused', accent: accent, selected: true),
                ],
              ),
              SizedBox(height: context.space(12)),
              ThreadSearchRow(accent: accent),
              SizedBox(height: context.space(12)),
              ThreadQuickChips(accent: accent),
              SizedBox(height: context.space(12)),
            ],
            Expanded(
              child: ProviderBody(
                status: status,
                errorMessage: provider.errorMessage,
                onRetry: provider.refresh,
                isEmpty: threads.isEmpty,
                emptyMessage: 'No messages yet.',
                child: ListView.builder(
                  itemCount: threads.length,
                  itemBuilder: (context, index) {
                    final thread = threads[index];
                    final selected = index == selectedIndex;
                    final latestMessage =
                        provider.latestMessageForThread(thread.id);
                    final participants = _filterParticipants(
                      thread.participants,
                      currentUserEmail,
                      context.tidingsSettings.hideSelfInThreadList,
                    );
                    return StaggeredFadeIn(
                      index: index,
                      child: Padding(
                        padding: EdgeInsets.only(bottom: context.space(8)),
                        child: ThreadTile(
                          thread: thread,
                          participants: participants,
                          latestMessage: latestMessage,
                          accent: accent,
                          selected: selected && !isCompact,
                          onTap: () => onSelected(index),
                        ),
                      ),
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
    required this.selected,
    required this.onTap,
  });

  final EmailThread thread;
  final List<EmailAddress> participants;
  final EmailMessage? latestMessage;
  final Color accent;
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
    final baseFill = widget.selected
        ? widget.accent.withValues(alpha: 0.16)
        : isUnread
            ? (isDark
                ? Colors.white.withValues(alpha: 0.14)
                : Colors.white.withValues(alpha: 0.7))
            : ColorTokens.cardFill(context, 0.04);
    final hoverOverlay = isDark
        ? Colors.white.withValues(alpha: _pressed ? 0.1 : 0.06)
        : Colors.black.withValues(alpha: _pressed ? 0.08 : 0.04);
    final fill = _hovered || _pressed
        ? Color.alphaBlend(hoverOverlay, baseFill)
        : baseFill;
    final borderColor = widget.selected
        ? widget.accent.withValues(alpha: 0.45)
        : ColorTokens.border(context, 0.12);
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
    final displayTime = _formatThreadTimestamp(
      widget.thread.receivedAt ?? latestMessage?.receivedAt,
      widget.thread.time,
    );
    final participants = _orderedParticipants(
      widget.participants,
      latestSender,
    );

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
          padding: EdgeInsets.all(context.space(12)),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(context.radius(16)),
            border: Border.all(color: borderColor),
          ),
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
                                SizedBox(width: context.space(12)),
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
                                          style: widget.participants[i].email ==
                                                  latestSender
                                              ? highlightParticipantStyle
                                              : baseParticipantStyle,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(width: context.space(8)),
                              Text(
                                displayTime,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: scheme.onSurface
                                          .withValues(alpha: 0.55),
                                    ),
                              ),
                            ],
                          ),
                          SizedBox(height: context.space(4)),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  subject,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: widget.selected
                                            ? scheme.onSurface
                                            : (widget.thread.unread
                                                ? scheme.onSurface
                                                : scheme.onSurface.withValues(
                                                    alpha: 0.5,
                                                  )),
                                      ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (widget.thread.starred)
                                Icon(
                                  Icons.star_rounded,
                                  color: widget.accent,
                                  size: 18,
                                ),
                            ],
                          ),
                          SizedBox(height: context.space(6)),
                          Text(
                            latestMessage?.bodyPlainText ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurface.withValues(
                                        alpha: widget.selected
                                            ? 0.7
                                            : (isUnread ? 0.62 : 0.34),
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

String _formatThreadTimestamp(DateTime? timestamp, String fallback) {
  if (timestamp == null) {
    return fallback;
  }
  final now = DateTime.now();
  final isToday = timestamp.year == now.year &&
      timestamp.month == now.month &&
      timestamp.day == now.day;
  final time = _formatClock(timestamp);
  if (isToday) {
    return time;
  }
  final month = _monthAbbrev[timestamp.month - 1];
  return '$month ${timestamp.day} $time';
}

String _formatClock(DateTime timestamp) {
  var hour = timestamp.hour;
  final minute = timestamp.minute;
  final suffix = hour >= 12 ? 'PM' : 'AM';
  hour = hour % 12;
  if (hour == 0) {
    hour = 12;
  }
  final minuteLabel = minute.toString().padLeft(2, '0');
  return '$hour:$minuteLabel $suffix';
}

const List<String> _monthAbbrev = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
