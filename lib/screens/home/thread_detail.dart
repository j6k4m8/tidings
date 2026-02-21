import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

import '../../models/email_models.dart';
import '../../providers/email_provider.dart';
import '../../providers/unified_email_provider.dart';
import '../../state/shortcut_definitions.dart';
import '../../state/send_queue.dart';
import '../../state/tidings_settings.dart';
import '../../utils/email_time.dart';
import '../../utils/subject_utils.dart';
import '../../theme/color_tokens.dart';
import '../../widgets/key_hint.dart';
import '../../widgets/tidings_background.dart';
import '../compose/compose_sheet.dart';
import '../compose/compose_utils.dart';
import '../compose/inline_reply_composer.dart';
import '../keyboard/move_to_folder_dialog.dart';
import 'provider_body.dart';

class CurrentThreadPanel extends StatefulWidget {
  const CurrentThreadPanel({
    super.key,
    required this.accent,
    required this.thread,
    required this.provider,
    required this.isCompact,
    required this.currentUserEmail,
    required this.selectedMessageIndex,
    required this.onMessageSelected,
    required this.isFocused,
    this.scrollController,
    this.parentFocusNode,
    this.replyController,
    this.onReplyFocusChange,
  });

  final Color accent;
  final EmailThread thread;
  final EmailProvider provider;
  final bool isCompact;
  final String currentUserEmail;
  final int selectedMessageIndex;
  final ValueChanged<int> onMessageSelected;
  final bool isFocused;
  final ScrollController? scrollController;
  final FocusNode? parentFocusNode;
  final InlineReplyController? replyController;
  final ValueChanged<bool>? onReplyFocusChange;

  @override
  State<CurrentThreadPanel> createState() => _CurrentThreadPanelState();
}

class _CurrentThreadPanelState extends State<CurrentThreadPanel> {
  final Map<String, bool> _expandedState = {};
  late ScrollController _scrollController;
  bool _ownsScrollController = false;
  bool _showEscHint = false;
  bool _wasFocused = false;
  static const int _headerSnippetMaxLength = 72;

  void _configureScrollController() {
    final external = widget.scrollController;
    if (external != null) {
      _scrollController = external;
      _ownsScrollController = false;
    } else {
      _scrollController = ScrollController();
      _ownsScrollController = true;
    }
  }

  @override
  void initState() {
    super.initState();
    _configureScrollController();
  }

  @override
  void dispose() {
    if (_ownsScrollController) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CurrentThreadPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      if (_ownsScrollController) {
        _scrollController.dispose();
      }
      _configureScrollController();
    }
    // Show hint when focus is gained (desktop only)
    if (widget.isFocused && !_wasFocused && !widget.isCompact) {
      _showEscHintBriefly();
    }
    _wasFocused = widget.isFocused;
  }

  void _showEscHintBriefly() {
    setState(() => _showEscHint = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _showEscHint = false);
      }
    });
  }

  String _participantHeadline(EmailThread thread) {
    final participants = thread.participants;
    if (participants.isEmpty) {
      return 'Unknown sender';
    }
    if (participants.length == 1) {
      return participants.first.displayName;
    }
    if (participants.length == 2) {
      return '${participants[0].displayName} & ${participants[1].displayName}';
    }
    return '${participants.first.displayName} & ${participants.length - 1} others';
  }

  String _cleanSnippet(String text, int maxLength) {
    final collapsed = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (collapsed.isEmpty) {
      return '';
    }
    if (collapsed.length <= maxLength) {
      return collapsed;
    }
    return '${collapsed.substring(0, maxLength).trimRight()}...';
  }

  String _buildHeaderSnippet(EmailThread thread, EmailMessage? latest) {
    final headline = _participantHeadline(thread);
    final subject = thread.subject.isEmpty ? 'No subject' : thread.subject;
    final snippet = _cleanSnippet(latest?.bodyPlainText ?? '', _headerSnippetMaxLength);
    if (snippet.isEmpty) {
      return '$headline: $subject';
    }
    return '$headline: $subject - $snippet';
  }

  bool _isExpanded(String messageId, bool defaultExpanded) {
    return _expandedState[messageId] ?? defaultExpanded;
  }

  void _setExpanded(String messageId, bool expanded) {
    setState(() {
      _expandedState[messageId] = expanded;
    });
  }

  String? _outboxIdForMessage(EmailMessage message) {
    const prefix = 'outbox-';
    if (!message.id.startsWith(prefix)) {
      return null;
    }
    return message.id.substring(prefix.length);
  }

  EmailProvider? _providerForOutboxItem(OutboxItem item) {
    final provider = widget.provider;
    if (provider is UnifiedEmailProvider) {
      return provider.providerForAccount(item.accountKey);
    }
    return provider;
  }

  EmailThread? _threadForOutboxItem(
    EmailProvider provider,
    OutboxItem item,
  ) {
    final threadId = item.threadId;
    if (threadId == null || threadId.isEmpty) {
      return null;
    }
    for (final thread in provider.threads) {
      if (thread.id == threadId) {
        return thread;
      }
    }
    return null;
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _toggleThreadRead() async {
    final messages = widget.provider.messagesForThread(widget.thread.id);
    final hasUnreadMessage = messages.any((message) => message.isUnread);
    final isUnread =
        messages.isNotEmpty ? hasUnreadMessage : widget.thread.unread;
    final error = await widget.provider.setThreadUnread(
      widget.thread,
      !isUnread,
    );
    if (error != null) {
      _toast(error);
      return;
    }
    _toast(isUnread ? 'Marked as read.' : 'Marked as unread.');
  }

  Future<void> _undoSend(String outboxId) async {
    final messenger = ScaffoldMessenger.of(context);
    await OutboxStore.instance.ensureLoaded();
    final item = OutboxStore.instance.findById(outboxId);
    if (item == null) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Unable to undo')),
        );
      }
      return;
    }
    final provider = _providerForOutboxItem(item);
    if (provider == null) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Unable to undo')),
        );
      }
      return;
    }
    var undone = false;
    try {
      undone = await provider.cancelSend(outboxId);
    } catch (_) {
      undone = false;
    }
    if (!mounted) {
      return;
    }
    if (!undone) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Unable to undo')),
      );
      return;
    }
    if (widget.replyController != null) {
      widget.replyController!.restoreDraftForThread(widget.thread.id, item);
      widget.replyController!.focusEditorForThread(widget.thread.id);
      return;
    }
    final thread = _threadForOutboxItem(provider, item);
    await showComposeSheet(
      messenger.context,
      provider: provider,
      accent: widget.accent,
      thread: thread,
      currentUserEmail: widget.currentUserEmail,
      initialTo: item.toLine,
      initialCc: item.ccLine,
      initialBcc: item.bccLine,
      initialSubject: item.subject,
      initialDelta: deltaFromPlainText(item.bodyText),
    );
  }

  void _toggleExpanded(String messageId, bool defaultExpanded) {
    final current = _isExpanded(messageId, defaultExpanded);
    _setExpanded(messageId, !current);
  }

  void _expandAll(List<EmailMessage> messages) {
    setState(() {
      for (final message in messages) {
        _expandedState[message.id] = true;
      }
    });
  }

  void _collapseAll(List<EmailMessage> messages) {
    setState(() {
      for (final message in messages) {
        _expandedState[message.id] = false;
      }
    });
  }

  Future<void> _handleMoveToFolder({EmailMessage? singleMessage}) async {
    final settings = context.tidingsSettings;
    // Resolve the real provider (not unified wrapper) so we get same-account
    // folders only.
    final provider = widget.provider;
    final realProvider = provider is UnifiedEmailProvider
        ? provider.providerForThread(widget.thread.id) ?? provider
        : provider;
    final messages = provider.messagesForThread(widget.thread.id);
    final entries = buildMoveToFolderEntries(
      realProvider.folderSections,
      currentFolderPath: provider.selectedFolderPath,
    );
    if (!mounted) {
      return;
    }
    final result = await showMoveToFolderDialog(
      context,
      accent: widget.accent,
      entries: entries,
      messageCount: messages.length,
      defaultMoveEntireThread: singleMessage == null
          ? true
          : settings.moveEntireThreadByDefault,
      // Only show the thread toggle when acting on a single message inside a
      // multi-message thread — otherwise the choice is meaningless.
      showThreadToggle: singleMessage != null && messages.length > 1,
    );
    if (result == null || !mounted) {
      return;
    }
    final effectiveSingleMessage =
        result.moveEntireThread ? null : singleMessage;
    final error = await provider.moveToFolder(
      widget.thread,
      result.folderPath,
      singleMessage: effectiveSingleMessage,
    );
    if (!mounted) {
      return;
    }
    if (error != null) {
      _toast('Move failed: $error');
      return;
    }
    _toast('Moved ${subjectLabel(widget.thread.subject)}');
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.tidingsSettings;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final panelRadius = context.radius(30);
    return AnimatedBuilder(
      animation: widget.provider,
      builder: (context, _) {
        final messages = widget.provider.messagesForThread(widget.thread.id);
        final latestMessage = messages.isNotEmpty
            ? messages.last
            : widget.provider.latestMessageForThread(widget.thread.id);
        final hasUnreadMessage = messages.any((message) => message.isUnread);
        final threadIsUnread =
            messages.isNotEmpty ? hasUnreadMessage : widget.thread.unread;
        final headerSnippet = _buildHeaderSnippet(widget.thread, latestMessage);
        return Stack(
          children: [
            // Outline border when focused
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                color: isDark ? scheme.surface : Colors.white,
                borderRadius: BorderRadius.circular(panelRadius),
                border: Border.all(
                  color: widget.isFocused
                      ? widget.accent.withValues(alpha: 0.4)
                      : scheme.outline.withValues(alpha: 0.1),
                  width: widget.isFocused ? 1.5 : 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(panelRadius - 1),
                child: Padding(
                  padding: EdgeInsets.all(
                    widget.isCompact ? context.space(16) : context.space(18),
                  ),
                  child: SelectionArea(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (widget.isCompact)
                              IconButton(
                                onPressed: () =>
                                    Navigator.of(context).maybePop(),
                                icon: const Icon(Icons.arrow_back_rounded),
                              ),
                            Expanded(
                              child: Text(
                                widget.thread.subject,
                                style: Theme.of(context).textTheme.titleMedium,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              onPressed: () {},
                              icon: const Icon(Icons.star_border_rounded),
                            ),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_horiz_rounded),
                              onSelected: (value) {
                                switch (value) {
                                  case 'expand_all':
                                    _expandAll(messages);
                                  case 'collapse_all':
                                    _collapseAll(messages);
                                  case 'move_to_folder':
                                    _handleMoveToFolder();
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'expand_all',
                                  child: Text('Expand all'),
                                ),
                                const PopupMenuItem(
                                  value: 'collapse_all',
                                  child: Text('Collapse all'),
                                ),
                                const PopupMenuItem(
                                  value: 'move_to_folder',
                                  child: Text('Move to folder…'),
                                ),
                              ],
                            ),
                          ],
                        ),
                        SizedBox(height: context.space(4)),
                        Text(
                          headerSnippet,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                        SizedBox(height: context.space(12)),
                        Expanded(
                          child: ProviderBody(
                            status: widget.provider.status,
                            errorMessage: widget.provider.errorMessage,
                            onRetry: widget.provider.refresh,
                            isEmpty: messages.isEmpty,
                            emptyMessage: 'No messages in this thread.',
                            child: ListView.separated(
                              controller: _scrollController,
                              padding:
                                  EdgeInsets.only(bottom: context.space(16)),
                              itemCount: messages.length,
                              separatorBuilder: (context, index) => Divider(
                                height: context.space(16),
                                thickness: 1,
                                color: ColorTokens.border(context, 0.1),
                              ),
                              itemBuilder: (context, index) {
                                final message = messages[index];
                                final isLatest = index == messages.length - 1;
                                final defaultExpanded =
                                    (settings.autoExpandLatest && isLatest) ||
                                    (settings.autoExpandUnread &&
                                        message.isUnread);
                                final outboxId = _outboxIdForMessage(message);
                                final canUndo = outboxId != null &&
                                    message.sendStatus ==
                                        MessageSendStatus.queued;
                                final undoId = canUndo ? outboxId : null;
                                return MessageCard(
                                  key: ValueKey(message.id),
                                  message: message,
                                  accent: widget.accent,
                                  threadIsUnread: threadIsUnread,
                                  expanded: _isExpanded(
                                    message.id,
                                    defaultExpanded,
                                  ),
                                  onToggleExpanded: () => _toggleExpanded(
                                    message.id,
                                    defaultExpanded,
                                  ),
                                  isSelected:
                                      index == widget.selectedMessageIndex,
                                  onSelected: () =>
                                      widget.onMessageSelected(index),
                                  onToggleRead: _toggleThreadRead,
                                  onUndoSend: undoId == null
                                      ? null
                                      : () => _undoSend(undoId),
                                  onMoveToFolder: () =>
                                      _handleMoveToFolder(singleMessage: message),
                                  showFolderSource:
                                      settings.showMessageFolderSource,
                                  currentFolderPath:
                                      widget.provider.selectedFolderPath,
                                );
                              },
                            ),
                          ),
                        ),
                        SizedBox(height: context.space(12)),
                        ComposeBar(
                          accent: widget.accent,
                          provider: widget.provider,
                          thread: widget.thread,
                          currentUserEmail: widget.currentUserEmail,
                          parentFocusNode: widget.parentFocusNode,
                          controller: widget.replyController,
                          onFocusChange: widget.onReplyFocusChange,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Esc hint overlay (desktop only)
            if (!widget.isCompact)
              Positioned(
                top: context.space(12),
                left: 0,
                right: 0,
                child: Center(
                  child: AnimatedOpacity(
                    opacity: _showEscHint ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: IgnorePointer(
                      child: KeyHintMessage(
                        keyLabel: 'esc',
                        message: 'to return to inbox',
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class MessageCard extends StatelessWidget {
  const MessageCard({
    super.key,
    required this.message,
    required this.accent,
    required this.threadIsUnread,
    required this.expanded,
    required this.onToggleExpanded,
    required this.isSelected,
    this.onSelected,
    this.onToggleRead,
    this.onUndoSend,
    this.onMoveToFolder,
    this.showFolderSource = false,
    this.currentFolderPath,
  });

  final EmailMessage message;
  final Color accent;
  final bool threadIsUnread;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final bool isSelected;
  final VoidCallback? onSelected;
  final VoidCallback? onToggleRead;
  final VoidCallback? onUndoSend;
  final VoidCallback? onMoveToFolder;
  final bool showFolderSource;
  final String? currentFolderPath;

  static const int _collapsedCharLimit = 420;

  // Patterns that indicate the start of a quoted reply
  static final _quotePatterns = [
    // "On <date>, <person> wrote:" style
    RegExp(r'^On .+ wrote:\s*$', multiLine: true),
    // "From: <person>" forwarded header
    RegExp(r'^From:\s+.+$', multiLine: true),
    // "> " quoted lines (3+ consecutive)
    RegExp(r'(?:^>\s?.*\n){3,}', multiLine: true),
    // "---- Original Message ----" divider
    RegExp(
      r'^-{2,}\s*Original Message\s*-{2,}',
      multiLine: true,
      caseSensitive: false,
    ),
    // Gmail style "---------- Forwarded message ---------"
    RegExp(
      r'^-{2,}\s*Forwarded message\s*-{2,}',
      multiLine: true,
      caseSensitive: false,
    ),
  ];

  /// Finds the index where quoted content begins, or -1 if not found.
  int _findQuoteBoundary(String text) {
    int earliest = -1;
    for (final pattern in _quotePatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final idx = match.start;
        if (earliest == -1 || idx < earliest) {
          earliest = idx;
        }
      }
    }
    return earliest;
  }

  /// Returns the portion of text before any quoted replies.
  String _textBeforeQuotes(String text) {
    final boundary = _findQuoteBoundary(text);
    if (boundary <= 0) {
      return text;
    }
    return text.substring(0, boundary).trimRight();
  }

  bool _isLongBody(String text, MessageCollapseMode mode, int maxLines) {
    if (mode == MessageCollapseMode.beforeQuotes) {
      // Long if there are quotes to truncate, or if body before quotes is still long
      final boundary = _findQuoteBoundary(text);
      if (boundary > 0) {
        return true;
      }
      // Fall back to line-based check if no quotes found
      final newlines = '\n'.allMatches(text).length;
      return newlines > maxLines || text.length > _collapsedCharLimit;
    }
    // maxLines mode
    if (text.length > _collapsedCharLimit) {
      return true;
    }
    final newlines = '\n'.allMatches(text).length;
    return newlines > maxLines;
  }

  double _collapsedHeight(BuildContext context, int maxLines) {
    final fontSize = Theme.of(context).textTheme.bodyLarge?.fontSize ?? 14;
    return maxLines * fontSize * 1.45;
  }

  double _collapsedHeightForQuotes(BuildContext context, String bodyText) {
    final textBeforeQuote = _textBeforeQuotes(bodyText);
    final lineCount = '\n'.allMatches(textBeforeQuote).length + 1;
    // Clamp to reasonable bounds (min 2 lines, max 12 lines)
    final clampedLines = lineCount.clamp(2, 12);
    final fontSize = Theme.of(context).textTheme.bodyLarge?.fontSize ?? 14;
    return clampedLines * fontSize * 1.45;
  }

  Widget _buildShowMoreButton(BuildContext context) {
    return Positioned(
      right: 0,
      bottom: 0,
      child: GestureDetector(
        onTap: onToggleExpanded,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: context.space(8),
            vertical: context.space(4),
          ),
          decoration: BoxDecoration(
            color: ColorTokens.cardFill(context, 0.12),
            borderRadius: BorderRadius.circular(context.radius(999)),
            border: Border.all(color: ColorTokens.border(context, 0.12)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.expand_more_rounded,
                size: 14,
                color: accent.withValues(alpha: 0.9),
              ),
              SizedBox(width: context.space(4)),
              Text(
                'Show more',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: accent.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMetadataDialog(BuildContext context) {
    final bodyHtml = message.bodyHtml;
    final bodyText = message.bodyText;
    final bodyPlainText = message.bodyPlainText;
    final sanitized = bodyHtml != null ? _sanitizeHtml(bodyHtml) : null;

    final metadata = StringBuffer()
      ..writeln('=== MESSAGE METADATA ===')
      ..writeln()
      ..writeln('ID: ${message.id}')
      ..writeln('Thread ID: ${message.threadId}')
      ..writeln('Subject: ${message.subject}')
      ..writeln('From: ${message.from.email}')
      ..writeln('Time: ${message.time}')
      ..writeln('Message-ID: ${message.messageId}')
      ..writeln('In-Reply-To: ${message.inReplyTo}')
      ..writeln('Send status: ${message.sendStatus}')
      ..writeln()
      ..writeln('=== BODY TEXT (raw field) ===')
      ..writeln('Length: ${bodyText?.length ?? 0}')
      ..writeln('Is null: ${bodyText == null}')
      ..writeln('Is empty: ${bodyText?.isEmpty ?? true}')
      ..writeln()
      ..writeln('--- Content (first 500 chars) ---')
      ..writeln(
        bodyText?.substring(0, bodyText.length.clamp(0, 500)) ?? '(null)',
      )
      ..writeln()
      ..writeln('=== BODY PLAIN TEXT (computed) ===')
      ..writeln('Length: ${bodyPlainText.length}')
      ..writeln('Is empty: ${bodyPlainText.isEmpty}')
      ..writeln()
      ..writeln('--- Content (first 500 chars) ---')
      ..writeln(bodyPlainText.substring(0, bodyPlainText.length.clamp(0, 500)))
      ..writeln()
      ..writeln('=== BODY HTML (raw field) ===')
      ..writeln('Length: ${bodyHtml?.length ?? 0}')
      ..writeln('Is null: ${bodyHtml == null}')
      ..writeln('Is empty: ${bodyHtml?.isEmpty ?? true}')
      ..writeln()
      ..writeln('--- Content (first 1000 chars) ---')
      ..writeln(
        bodyHtml?.substring(0, bodyHtml.length.clamp(0, 1000)) ?? '(null)',
      )
      ..writeln()
      ..writeln('=== SANITIZED HTML ===')
      ..writeln('Length: ${sanitized?.length ?? 0}')
      ..writeln('Is null: ${sanitized == null}')
      ..writeln('Is empty: ${sanitized?.isEmpty ?? true}')
      ..writeln(
        'Has HTML tags: ${sanitized?.contains(RegExp(r"<[a-zA-Z]")) ?? false}',
      )
      ..writeln()
      ..writeln('--- Content (first 1000 chars) ---')
      ..writeln(
        sanitized?.substring(0, sanitized.length.clamp(0, 1000)) ?? '(null)',
      );

    final content = metadata.toString();

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Message Metadata'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: SingleChildScrollView(
            child: SelectableText(
              content,
              style: const TextStyle(fontFamily: 'SF Mono', fontSize: 11),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: content));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied to clipboard')),
              );
            },
            child: const Text('Copy All'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _sanitizeHtml(String html) {
    var value = html;

    // Remove scripts (security)
    value = value.replaceAll(
      RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false),
      '',
    );

    // Remove event handlers (security)
    value = value.replaceAll(
      RegExp(r'\s+on\w+\s*=\s*"[^"]*"', caseSensitive: false),
      '',
    );
    value = value.replaceAll(
      RegExp(r"\s+on\w+\s*=\s*'[^']*'", caseSensitive: false),
      '',
    );

    return value.trim();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settings = context.tidingsSettings;
    final showSubject = !settings.hideThreadSubjects;
    final collapseMode = settings.messageCollapseMode;
    final maxLines = settings.collapsedMaxLines;
    final toggleReadLabel = threadIsUnread ? 'Mark as Read' : 'Mark as Unread';
    final toggleReadHint =
        settings.shortcutLabel(ShortcutAction.toggleRead, includeSecondary: false);
    final cardRadius = context.radius(12);
    final bodyText = message.bodyPlainText;
    final bodyHtml = message.bodyHtml;
    final shouldClamp =
        !expanded && _isLongBody(bodyText, collapseMode, maxLines);

    // Left border for "from me" messages: use a decoration border so it
    // works naturally with border radius and doesn't overlap padded text.
    final Border? isMeBorder = (!isSelected && message.isMe)
        ? Border(
            left: BorderSide(
              color: accent.withValues(alpha: 0.35),
              width: 2.5,
            ),
          )
        : null;

    return GestureDetector(
      onTap: onSelected,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(cardRadius),
          border: isSelected
              ? Border.all(color: accent.withValues(alpha: 0.5), width: 1.5)
              : isMeBorder,
        ),
        child: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
            // Extra left padding when isMe so text doesn't sit on the border.
            (!isSelected && message.isMe)
                ? context.space(12)
                : context.space(10),
            context.space(10),
            context.space(10),
            context.space(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                  Row(
                    children: [
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final nameMaxWidth =
                                (constraints.maxWidth * 0.6).clamp(
                                      120.0,
                                      constraints.maxWidth,
                                    );
                            return Wrap(
                              spacing: context.space(8),
                              runSpacing: context.space(2),
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                ConstrainedBox(
                                  constraints:
                                      BoxConstraints(maxWidth: nameMaxWidth),
                                  child: Text(
                                    message.from.displayName,
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  () {
                                    final s = context.tidingsSettings;
                                    final ts = message.receivedAt;
                                    return ts != null
                                        ? formatEmailTime(ts, dateOrder: s.dateOrder, use24h: s.use24HourTime)
                                        : message.time;
                                  }(),
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: scheme.onSurface
                                            .withValues(alpha: 0.6),
                                      ),
                                ),
                                if (message.sendStatus != null)
                                  _SendStatusChip(
                                    status: message.sendStatus!,
                                    accent: accent,
                                  ),
                                if (showFolderSource &&
                                    message.folderPath != null &&
                                    message.folderPath!.isNotEmpty &&
                                    message.folderPath != currentFolderPath)
                                  _FolderSourceChip(
                                    folderPath: message.folderPath!,
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_horiz_rounded,
                          color: scheme.onSurface.withValues(alpha: 0.5),
                        ),
                        padding: EdgeInsets.zero,
                        onSelected: (value) {
                          if (value == 'toggle') {
                            onToggleExpanded();
                          } else if (value == 'toggle-read') {
                            onToggleRead?.call();
                          } else if (value == 'move') {
                            onMoveToFolder?.call();
                          } else if (value == 'metadata') {
                            _showMetadataDialog(context);
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'toggle',
                            child: Text(expanded ? 'Collapse' : 'Expand'),
                          ),
                          PopupMenuItem(
                            value: 'toggle-read',
                            enabled: onToggleRead != null,
                            child: Row(
                              children: [
                                Expanded(child: Text(toggleReadLabel)),
                                SizedBox(width: context.space(8)),
                                KeyHint(keyLabel: toggleReadHint, small: true),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'move',
                            enabled: onMoveToFolder != null,
                            child: const Text('Move to folder…'),
                          ),
                          const PopupMenuItem(
                            value: 'metadata',
                            child: Text('View metadata'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: context.space(6)),
                  if (onUndoSend != null) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: onUndoSend,
                        icon: const Icon(Icons.undo_rounded, size: 16),
                        label: const Text('Undo send'),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            horizontal: context.space(6),
                            vertical: 0,
                          ),
                          minimumSize: Size(0, context.space(28)),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ),
                    SizedBox(height: context.space(4)),
                  ],
                  if (showSubject) ...[
                    Text(
                      message.subject,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: context.space(6)),
                  ],
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) =>
                        FadeTransition(opacity: animation, child: child),
                    child: LayoutBuilder(
                      key: ValueKey(
                        'body-${expanded ? 'expanded' : 'collapsed'}-$collapseMode',
                      ),
                      builder: (context, constraints) {
                        final boundedWidth = constraints.maxWidth.isFinite;

                        final hasTextContent = bodyText.isNotEmpty;

                        Widget contentWidget;

                        if (bodyHtml != null && bodyHtml.trim().isNotEmpty) {
                          final sanitized = _sanitizeHtml(bodyHtml);
                          if (sanitized.isNotEmpty) {
                            contentWidget = HtmlWidget(
                              sanitized,
                              textStyle: Theme.of(context).textTheme.bodyLarge,
                              onTapUrl: (url) {
                                final uri = Uri.tryParse(url);
                                if (uri != null) {
                                  launchUrl(
                                    uri,
                                    mode: LaunchMode.externalApplication,
                                  );
                                }
                                return true;
                              },
                              customStylesBuilder: (element) {
                                switch (element.localName) {
                                  case 'a':
                                    return {'color': '#1a73e8'};
                                  case 'img':
                                  case 'video':
                                  case 'iframe':
                                  case 'table':
                                    return {'max-width': '100%'};
                                  case 'pre':
                                    return {
                                      'white-space': 'pre-wrap',
                                      'word-break': 'break-word',
                                    };
                                  case 'code':
                                    return {
                                      'font-family':
                                          'SF Mono, Menlo, monospace',
                                    };
                                }
                                return null;
                              },
                            );
                          } else {
                            contentWidget = Text(
                              bodyText,
                              style: Theme.of(context).textTheme.bodyLarge,
                            );
                          }
                        } else if (hasTextContent) {
                          contentWidget = Text(
                            bodyText,
                            style: Theme.of(context).textTheme.bodyLarge,
                          );
                        } else {
                          contentWidget = Text(
                            '[No content]',
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(
                                  fontStyle: FontStyle.italic,
                                  color:
                                      scheme.onSurface.withValues(alpha: 0.5),
                                ),
                          );
                        }
                        final content = ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth: boundedWidth ? constraints.maxWidth : 0,
                            maxWidth: boundedWidth
                                ? constraints.maxWidth
                                : double.infinity,
                          ),
                          child: contentWidget,
                        );

                        if (!shouldClamp) {
                          return content;
                        }

                        // Compute collapsed height based on mode
                        final collapsedHeight =
                            collapseMode == MessageCollapseMode.beforeQuotes
                            ? _collapsedHeightForQuotes(context, bodyText)
                            : _collapsedHeight(context, maxLines);

                        return Stack(
                          children: [
                            ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(context.radius(4)),
                              child: SizedBox(
                                height: collapsedHeight,
                                width:
                                    boundedWidth ? constraints.maxWidth : null,
                                child: SingleChildScrollView(
                                  physics:
                                      const NeverScrollableScrollPhysics(),
                                  child: content,
                                ),
                              ),
                            ),
                            _buildShowMoreButton(context),
                          ],
                        );
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

class _SendStatusChip extends StatelessWidget {
  const _SendStatusChip({required this.status, required this.accent});

  final MessageSendStatus status;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = switch (status) {
      MessageSendStatus.queued => 'Queued',
      MessageSendStatus.sending => 'Sending',
      MessageSendStatus.failed => 'Failed',
    };
    final color = status == MessageSendStatus.failed
        ? Colors.redAccent
        : accent.withValues(alpha: 0.9);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.space(6),
        vertical: context.space(2),
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(context.radius(999)),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.7),
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _FolderSourceChip extends StatelessWidget {
  const _FolderSourceChip({required this.folderPath});

  final String folderPath;

  /// Returns the last path segment as a human-friendly display name.
  String get _displayName {
    final parts = folderPath.split('/');
    return parts.last.isEmpty ? folderPath : parts.last;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = scheme.onSurface;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.space(6),
        vertical: context.space(2),
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.1 : 0.07),
        borderRadius: BorderRadius.circular(context.radius(999)),
        border: Border.all(color: color.withValues(alpha: isDark ? 0.2 : 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.folder_outlined,
            size: 11,
            color: color.withValues(alpha: 0.55),
          ),
          SizedBox(width: context.space(3)),
          Text(
            _displayName,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color.withValues(alpha: 0.6),
                ),
          ),
        ],
      ),
    );
  }
}

class ComposeBar extends StatelessWidget {
  const ComposeBar({
    super.key,
    required this.accent,
    required this.provider,
    required this.thread,
    required this.currentUserEmail,
    this.parentFocusNode,
    this.controller,
    this.onFocusChange,
  });

  final Color accent;
  final EmailProvider provider;
  final EmailThread thread;
  final String currentUserEmail;
  final FocusNode? parentFocusNode;
  final InlineReplyController? controller;
  final ValueChanged<bool>? onFocusChange;

  @override
  Widget build(BuildContext context) {
    return InlineReplyComposer(
      accent: accent,
      provider: provider,
      thread: thread,
      currentUserEmail: currentUserEmail,
      parentFocusNode: parentFocusNode,
      controller: controller,
      onFocusChange: onFocusChange,
    );
  }
}

class ThreadScreen extends StatefulWidget {
  const ThreadScreen({
    super.key,
    required this.accent,
    required this.thread,
    required this.provider,
    required this.currentUserEmail,
  });

  final Color accent;
  final EmailThread thread;
  final EmailProvider provider;
  final String currentUserEmail;

  @override
  State<ThreadScreen> createState() => _ThreadScreenState();
}

class _ThreadScreenState extends State<ThreadScreen> {
  final InlineReplyController _replyController = InlineReplyController();
  bool _inlineReplyFocused = false;
  final FocusNode _shortcutFocusNode =
      FocusNode(debugLabel: 'ThreadScreenShortcuts');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _shortcutFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _shortcutFocusNode.dispose();
    super.dispose();
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
        context.findAncestorWidgetOfExactType<QuillEditor>() != null ||
        context.findAncestorWidgetOfExactType<InlineReplyComposer>() != null;
  }

  Map<LogicalKeySet, Intent> _shortcutMap(
    TidingsSettings settings, {
    required bool allowGlobal,
  }) {
    final shortcuts = <LogicalKeySet, Intent>{};
    void addShortcut(ShortcutAction action, Intent intent) {
      if (!allowGlobal) {
        return;
      }
      shortcuts[settings.shortcutFor(action).toKeySet()] = intent;
      final secondary = settings.secondaryShortcutFor(action);
      if (secondary != null) {
        shortcuts[secondary.toKeySet()] = intent;
      }
    }

    addShortcut(
      ShortcutAction.reply,
      const _ReplyIntent(ReplyMode.reply),
    );
    addShortcut(
      ShortcutAction.replyAll,
      const _ReplyIntent(ReplyMode.replyAll),
    );
    addShortcut(
      ShortcutAction.forward,
      const _ReplyIntent(ReplyMode.forward),
    );
    addShortcut(
      ShortcutAction.toggleRead,
      const _ToggleReadIntent(),
    );
    shortcuts[LogicalKeySet(LogicalKeyboardKey.escape)] = const _PopIntent();
    return shortcuts;
  }

  void _triggerReply(ReplyMode mode) {
    final threadId = widget.thread.id;
    _replyController.setModeForThread(threadId, mode);
    _replyController.focusEditorForThread(threadId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _replyController.setModeForThread(threadId, mode);
      _replyController.focusEditorForThread(threadId);
    });
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _toggleThreadRead() async {
    final messages = widget.provider.messagesForThread(widget.thread.id);
    final hasUnreadMessage = messages.any((message) => message.isUnread);
    final isUnread =
        messages.isNotEmpty ? hasUnreadMessage : widget.thread.unread;
    final error = await widget.provider.setThreadUnread(
      widget.thread,
      !isUnread,
    );
    if (error != null) {
      _toast(error);
      return;
    }
    _toast(isUnread ? 'Marked as read.' : 'Marked as unread.');
  }

  void _handleInlineReplyFocusChange(bool hasFocus) {
    if (_inlineReplyFocused == hasFocus) {
      return;
    }
    setState(() {
      _inlineReplyFocused = hasFocus;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final messages = widget.provider.messagesForThread(widget.thread.id);
    final selectedMessageIndex = messages.isEmpty ? 0 : messages.length - 1;
    final settings = context.tidingsSettings;
    final allowGlobal = !_isTextInputFocused() && !_inlineReplyFocused;
    return Shortcuts(
      shortcuts: _shortcutMap(settings, allowGlobal: allowGlobal),
      child: Actions(
        actions: {
          _PopIntent: CallbackAction<_PopIntent>(
            onInvoke: (intent) {
              if (!_isTextInputFocused()) {
                Navigator.of(context).maybePop();
              }
              return null;
            },
          ),
          _ReplyIntent: CallbackAction<_ReplyIntent>(
            onInvoke: (intent) {
              _triggerReply(intent.mode);
              return null;
            },
          ),
          _ToggleReadIntent: CallbackAction<_ToggleReadIntent>(
            onInvoke: (intent) {
              _toggleThreadRead();
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          canRequestFocus: true,
          focusNode: _shortcutFocusNode,
          child: Scaffold(
            body: AnnotatedRegion<SystemUiOverlayStyle>(
              value: SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: isDark
                    ? Brightness.light
                    : Brightness.dark,
                statusBarBrightness:
                    isDark ? Brightness.dark : Brightness.light,
              ),
              child: TidingsBackground(
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      context.gutter(16),
                      MediaQuery.of(context).padding.top + context.space(12),
                      context.gutter(16),
                      context.gutter(16),
                    ),
                    child: CurrentThreadPanel(
                      accent: widget.accent,
                      thread: widget.thread,
                      provider: widget.provider,
                      isCompact: true,
                      currentUserEmail: widget.currentUserEmail,
                      selectedMessageIndex: selectedMessageIndex,
                      onMessageSelected: (_) {},
                      isFocused: true,
                      replyController: _replyController,
                      onReplyFocusChange: _handleInlineReplyFocusChange,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PopIntent extends Intent {
  const _PopIntent();
}

class _ReplyIntent extends Intent {
  const _ReplyIntent(this.mode);

  final ReplyMode mode;
}

class _ToggleReadIntent extends Intent {
  const _ToggleReadIntent();
}
