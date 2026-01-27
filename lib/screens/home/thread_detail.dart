import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../models/email_models.dart';
import '../../providers/email_provider.dart';
import '../../state/tidings_settings.dart';
import '../../theme/color_tokens.dart';
import '../../widgets/key_hint.dart';
import '../../widgets/tidings_background.dart';
import '../compose/inline_reply_composer.dart';
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
    this.parentFocusNode,
    this.replyController,
  });

  final Color accent;
  final EmailThread thread;
  final EmailProvider provider;
  final bool isCompact;
  final String currentUserEmail;
  final int selectedMessageIndex;
  final ValueChanged<int> onMessageSelected;
  final bool isFocused;
  final FocusNode? parentFocusNode;
  final InlineReplyController? replyController;

  @override
  State<CurrentThreadPanel> createState() => _CurrentThreadPanelState();
}

class _CurrentThreadPanelState extends State<CurrentThreadPanel> {
  final Map<String, bool> _expandedState = {};
  final ScrollController _scrollController = ScrollController();
  bool _showEscHint = false;
  bool _wasFocused = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CurrentThreadPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
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

  bool _isExpanded(String messageId, bool defaultExpanded) {
    return _expandedState[messageId] ?? defaultExpanded;
  }

  void _setExpanded(String messageId, bool expanded) {
    setState(() {
      _expandedState[messageId] = expanded;
    });
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
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (widget.isCompact)
                        IconButton(
                          onPressed: () => Navigator.of(context).maybePop(),
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
                    ],
                  ),
                ],
              ),
              SizedBox(height: context.space(4)),
              Text(
                widget.thread.participantSummary,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color:
                          Theme.of(context).colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
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
                    padding: EdgeInsets.only(bottom: context.space(16)),
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
                          (settings.autoExpandUnread && message.isUnread);
                      return MessageCard(
                        key: ValueKey(message.id),
                        message: message,
                        accent: widget.accent,
                        expanded: _isExpanded(message.id, defaultExpanded),
                        onToggleExpanded: () =>
                            _toggleExpanded(message.id, defaultExpanded),
                        isSelected: index == widget.selectedMessageIndex,
                        onSelected: () => widget.onMessageSelected(index),
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
              ),
            ],
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
    required this.expanded,
    required this.onToggleExpanded,
    required this.isSelected,
    this.onSelected,
  });

  final EmailMessage message;
  final Color accent;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final bool isSelected;
  final VoidCallback? onSelected;

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
    RegExp(r'^-{2,}\s*Original Message\s*-{2,}', multiLine: true, caseSensitive: false),
    // Gmail style "---------- Forwarded message ---------"
    RegExp(r'^-{2,}\s*Forwarded message\s*-{2,}', multiLine: true, caseSensitive: false),
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
    final fontSize =
        Theme.of(context).textTheme.bodyLarge?.fontSize ?? 14;
    return maxLines * fontSize * 1.45;
  }

  double _collapsedHeightForQuotes(BuildContext context, String bodyText) {
    final textBeforeQuote = _textBeforeQuotes(bodyText);
    final lineCount = '\n'.allMatches(textBeforeQuote).length + 1;
    // Clamp to reasonable bounds (min 2 lines, max 12 lines)
    final clampedLines = lineCount.clamp(2, 12);
    final fontSize =
        Theme.of(context).textTheme.bodyLarge?.fontSize ?? 14;
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
            border: Border.all(
              color: ColorTokens.border(context, 0.12),
            ),
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
      ..writeln()
      ..writeln('=== BODY TEXT (raw field) ===')
      ..writeln('Length: ${bodyText?.length ?? 0}')
      ..writeln('Is null: ${bodyText == null}')
      ..writeln('Is empty: ${bodyText?.isEmpty ?? true}')
      ..writeln()
      ..writeln('--- Content (first 500 chars) ---')
      ..writeln(bodyText?.substring(0, bodyText.length.clamp(0, 500)) ?? '(null)')
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
      ..writeln(bodyHtml?.substring(0, bodyHtml.length.clamp(0, 1000)) ?? '(null)')
      ..writeln()
      ..writeln('=== SANITIZED HTML ===')
      ..writeln('Length: ${sanitized?.length ?? 0}')
      ..writeln('Is null: ${sanitized == null}')
      ..writeln('Is empty: ${sanitized?.isEmpty ?? true}')
      ..writeln('Has HTML tags: ${sanitized?.contains(RegExp(r"<[a-zA-Z]")) ?? false}')
      ..writeln()
      ..writeln('--- Content (first 1000 chars) ---')
      ..writeln(sanitized?.substring(0, sanitized.length.clamp(0, 1000)) ?? '(null)');

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
              style: const TextStyle(
                fontFamily: 'SF Mono',
                fontSize: 11,
              ),
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
    final cardRadius = context.radius(12);
    final bodyText = message.bodyPlainText;
    final bodyHtml = message.bodyHtml;
    final shouldClamp = !expanded && _isLongBody(bodyText, collapseMode, maxLines);

    return GestureDetector(
      onTap: onSelected,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.all(context.space(10)),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(cardRadius),
          border: isSelected
              ? Border.all(
                  color: accent.withValues(alpha: 0.5),
                  width: 1.5,
                )
              : message.isMe
                  ? Border(
                      left: BorderSide(
                        color: accent.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    )
                  : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  message.from.displayName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                SizedBox(width: context.space(8)),
                Text(
                  message.time,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.6),
                      ),
                ),
                const Spacer(),
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_horiz_rounded,
                    color: scheme.onSurface.withValues(alpha: 0.5),
                  ),
                  padding: EdgeInsets.zero,
                  onSelected: (value) {
                    if (value == 'toggle') {
                      onToggleExpanded();
                    } else if (value == 'metadata') {
                      _showMetadataDialog(context);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'toggle',
                      child: Text(expanded ? 'Collapse' : 'Expand'),
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
                key: ValueKey('body-${expanded ? 'expanded' : 'collapsed'}-$collapseMode'),
                builder: (context, constraints) {
                  final boundedWidth = constraints.maxWidth.isFinite;

                  final hasTextContent = bodyText.isNotEmpty;

                  Widget contentWidget;

                  if (bodyHtml != null && bodyHtml.trim().isNotEmpty) {
                    // Render HTML in WebView - preserves original styling
                    // Parent ScrollView handles scrolling, not the WebView
                    contentWidget = _HtmlWebView(
                      html: bodyHtml,
                      messageId: message.id,
                    );
                  } else if (hasTextContent) {
                    contentWidget = Text(
                      bodyText,
                      style: Theme.of(context).textTheme.bodyLarge,
                    );
                  } else {
                    contentWidget = Text(
                      '[No content]',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: scheme.onSurface.withValues(alpha: 0.5),
                      ),
                    );
                  }
                  final content = ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: boundedWidth ? constraints.maxWidth : 0,
                      maxWidth:
                          boundedWidth ? constraints.maxWidth : double.infinity,
                    ),
                    child: contentWidget,
                  );

                  if (!shouldClamp) {
                    return content;
                  }

                  // Compute collapsed height based on mode
                  final collapsedHeight = collapseMode == MessageCollapseMode.beforeQuotes
                      ? _collapsedHeightForQuotes(context, bodyText)
                      : _collapsedHeight(context, maxLines);

                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(context.radius(4)),
                        child: SizedBox(
                          height: collapsedHeight,
                          width: boundedWidth ? constraints.maxWidth : null,
                          child: SingleChildScrollView(
                            physics: const NeverScrollableScrollPhysics(),
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
  });

  final Color accent;
  final EmailProvider provider;
  final EmailThread thread;
  final String currentUserEmail;
  final FocusNode? parentFocusNode;
  final InlineReplyController? controller;

  @override
  Widget build(BuildContext context) {
    return InlineReplyComposer(
      accent: accent,
      provider: provider,
      thread: thread,
      currentUserEmail: currentUserEmail,
      parentFocusNode: parentFocusNode,
      controller: controller,
    );
  }
}

class ThreadScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final messages = provider.messagesForThread(thread.id);
    final selectedMessageIndex =
        messages.isEmpty ? 0 : messages.length - 1;
    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.escape): const _PopIntent(),
      },
      child: Actions(
        actions: {
          _PopIntent: CallbackAction<_PopIntent>(
            onInvoke: (intent) {
              Navigator.of(context).maybePop();
              return null;
            },
          ),
        },
        child: Scaffold(
          body: AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness:
                  isDark ? Brightness.light : Brightness.dark,
              statusBarBrightness:
                  isDark ? Brightness.dark : Brightness.light,
            ),
            child: TidingsBackground(
              accent: accent,
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
                    accent: accent,
                    thread: thread,
                    provider: provider,
                    isCompact: true,
                    currentUserEmail: currentUserEmail,
                    selectedMessageIndex: selectedMessageIndex,
                    onMessageSelected: (_) {},
                    isFocused: true,
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

/// WebView that renders HTML and auto-sizes to content height.
class _HtmlWebView extends StatefulWidget {
  const _HtmlWebView({
    required this.html,
    required this.messageId,
  });

  final String html;
  final String messageId;

  @override
  State<_HtmlWebView> createState() => _HtmlWebViewState();
}

class _HtmlWebViewState extends State<_HtmlWebView> {
  late final WebViewController _controller;
  double _contentHeight = 100;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            // Open external links in browser
            if (request.url != 'about:blank' &&
                !request.url.startsWith('data:')) {
              final uri = Uri.tryParse(request.url);
              if (uri != null) {
                launchUrl(uri, mode: LaunchMode.externalApplication);
              }
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onPageFinished: (_) => _measureHeight(),
        ),
      )
      ..addJavaScriptChannel(
        'FlutterHeight',
        onMessageReceived: (message) {
          final height = double.tryParse(message.message);
          if (height != null && height > 0 && mounted) {
            setState(() => _contentHeight = height);
          }
        },
      );
    _loadContent();
  }

  void _loadContent() {
    final html = '''
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<style>
html, body { margin: 0; padding: 0; overflow: hidden; }
body { padding: 4px; font-family: -apple-system, system-ui, sans-serif; font-size: 14px; line-height: 1.4; }
img { max-width: 100%; height: auto; }
table { max-width: 100%; border-collapse: collapse; }
a { color: #1a73e8; }
</style>
</head>
<body>
${widget.html}
<script>
function reportHeight() {
  var h = document.body.scrollHeight;
  if (window.FlutterHeight) FlutterHeight.postMessage(String(h));
}
reportHeight();
window.onload = reportHeight;
document.querySelectorAll('img').forEach(function(img) {
  img.onload = reportHeight;
  img.onerror = reportHeight;
});
setTimeout(reportHeight, 100);
setTimeout(reportHeight, 500);
</script>
</body>
</html>
''';
    _controller.loadHtmlString(html);
  }

  Future<void> _measureHeight() async {
    try {
      final result = await _controller.runJavaScriptReturningResult(
        'document.body.scrollHeight',
      );
      final height = double.tryParse(result.toString());
      if (height != null && height > 0 && mounted) {
        setState(() => _contentHeight = height);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _contentHeight,
      child: WebViewWidget(controller: _controller),
    );
  }
}
