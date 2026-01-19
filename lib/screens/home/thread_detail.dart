import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/email_models.dart';
import '../../providers/email_provider.dart';
import '../../state/tidings_settings.dart';
import '../../theme/color_tokens.dart';
import '../../theme/glass.dart';
import '../../widgets/tidings_background.dart';
import '../compose/inline_reply_composer.dart';
import 'provider_body.dart';

class CurrentThreadPanel extends StatelessWidget {
  const CurrentThreadPanel({
    super.key,
    required this.accent,
    required this.thread,
    required this.provider,
    required this.isCompact,
    required this.currentUserEmail,
  });

  final Color accent;
  final EmailThread thread;
  final EmailProvider provider;
  final bool isCompact;
  final String currentUserEmail;

  @override
  Widget build(BuildContext context) {
    final settings = context.tidingsSettings;
    return AnimatedBuilder(
      animation: provider,
      builder: (context, _) {
        final messages = provider.messagesForThread(thread.id);
        return GlassPanel(
          borderRadius: BorderRadius.circular(context.radius(30)),
          padding: EdgeInsets.all(
            isCompact ? context.space(16) : context.space(18),
          ),
          variant: GlassVariant.sheet,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (isCompact)
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                  Expanded(
                    child: Text(
                      thread.subject,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.star_border_rounded),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.more_horiz_rounded),
                  ),
                ],
              ),
              SizedBox(height: context.space(4)),
              Text(
                thread.participantSummary,
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
                  status: provider.status,
                  errorMessage: provider.errorMessage,
                  onRetry: provider.refresh,
                  isEmpty: messages.isEmpty,
                  emptyMessage: 'No messages in this thread.',
                  child: ListView.separated(
                    itemCount: messages.length,
                    separatorBuilder: (_, __) => Divider(
                      height: context.space(16),
                      thickness: 1,
                      color: ColorTokens.border(context, 0.1),
                    ),
                    itemBuilder: (context, index) {
                      final message = messages[index];
                        final isLatest = index == messages.length - 1;
                        final shouldExpand =
                          (settings.autoExpandLatest && isLatest) ||
                          (settings.autoExpandUnread && message.isUnread);
                      return MessageCard(
                        key: ValueKey(message.id),
                        message: message,
                        accent: accent,
                        shouldAutoExpand: shouldExpand,
                      );
                    },
                  ),
                ),
              ),
              SizedBox(height: context.space(12)),
              ComposeBar(
                accent: accent,
                provider: provider,
                thread: thread,
                currentUserEmail: currentUserEmail,
              ),
            ],
          ),
        );
      },
    );
  }
}

class MessageCard extends StatefulWidget {
  const MessageCard({
    super.key,
    required this.message,
    required this.accent,
    required this.shouldAutoExpand,
  });

  final EmailMessage message;
  final Color accent;
  final bool shouldAutoExpand;

  @override
  State<MessageCard> createState() => _MessageCardState();
}

class _MessageCardState extends State<MessageCard> {
  late bool _expanded;
  late bool _lastAutoExpand;
  static const int _collapsedLineLimit = 6;
  static const int _collapsedCharLimit = 420;
  static const int _collapsedNewlineLimit = 6;

  @override
  void initState() {
    super.initState();
    _expanded = widget.shouldAutoExpand;
    _lastAutoExpand = widget.shouldAutoExpand;
  }

  @override
  void didUpdateWidget(covariant MessageCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message.id != widget.message.id) {
      _expanded = widget.shouldAutoExpand;
      _lastAutoExpand = widget.shouldAutoExpand;
      return;
    }
    if (widget.shouldAutoExpand != _lastAutoExpand) {
      _expanded = widget.shouldAutoExpand;
      _lastAutoExpand = widget.shouldAutoExpand;
    }
  }

  void _toggle() {
    setState(() {
      _expanded = !_expanded;
    });
  }

  Future<void> _handleLinkTap(String? url) async {
    if (url == null || url.isEmpty) {
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  bool _isLongBody(String text) {
    if (text.length > _collapsedCharLimit) {
      return true;
    }
    final newlines = '\n'.allMatches(text).length;
    return newlines > _collapsedNewlineLimit;
  }

  double _collapsedHeight(BuildContext context) {
    final fontSize =
        Theme.of(context).textTheme.bodyLarge?.fontSize ?? 14;
    return _collapsedLineLimit * fontSize * 1.45;
  }

  String _sanitizeHtml(String html) {
    var value = html;
    value = value.replaceAll(
      RegExp(r'<!doctype[^>]*>', caseSensitive: false),
      '',
    );
    value = value.replaceAll(
      RegExp(r'<(script|style)[^>]*>[\s\S]*?</\1>', caseSensitive: false),
      '',
    );
    value = value.replaceAll(
      RegExp(r'<head[^>]*>[\s\S]*?</head>', caseSensitive: false),
      '',
    );
    return value.trim();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final showSubject = !context.tidingsSettings.hideThreadSubjects;
    final cardColor = widget.message.isMe
        ? widget.accent.withValues(alpha: 0.08)
        : Colors.transparent;
    final bodyText = widget.message.bodyPlainText;
    final bodyHtml = widget.message.bodyHtml;
    final hasHtml = bodyHtml != null && bodyHtml.trim().isNotEmpty;
    final sanitizedHtml = hasHtml ? _sanitizeHtml(bodyHtml!) : null;
    final shouldClamp = !_expanded && _isLongBody(bodyText);

    return GestureDetector(
      onTap: _toggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.all(context.space(10)),
        decoration: BoxDecoration(
          color: cardColor,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  widget.message.from.displayName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                SizedBox(width: context.space(8)),
                Text(
                  widget.message.time,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.6),
                      ),
                ),
                const Spacer(),
                Icon(
                  Icons.more_horiz_rounded,
                  color: scheme.onSurface.withValues(alpha: 0.5),
                ),
              ],
            ),
            SizedBox(height: context.space(6)),
            if (showSubject) ...[
              Text(
                widget.message.subject,
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
                key: ValueKey('body-${_expanded ? 'expanded' : 'collapsed'}'),
                builder: (context, constraints) {
                  final boundedWidth = constraints.maxWidth.isFinite;
                  final htmlWidget = (hasHtml && sanitizedHtml!.isNotEmpty)
                      ? Html(
                          data: sanitizedHtml,
                          shrinkWrap: true,
                          onLinkTap: (url, attributes, element) =>
                              _handleLinkTap(url),
                          style: {
                            'html': Style(
                              margin: Margins.zero,
                              padding: HtmlPaddings.zero,
                              backgroundColor: Colors.transparent,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            'body': Style(
                              margin: Margins.zero,
                              padding: HtmlPaddings.zero,
                              fontSize: FontSize(
                                Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.fontSize ??
                                    14,
                              ),
                              fontWeight: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.fontWeight,
                              color: Theme.of(context).colorScheme.onSurface,
                              backgroundColor: Colors.transparent,
                            ),
                            'p': Style(
                              margin: Margins.only(bottom: 8),
                              color:
                                  Theme.of(context).colorScheme.onSurface,
                            ),
                            'img': Style(
                              width: Width.auto(),
                              display: Display.block,
                              margin: Margins.only(bottom: 8),
                            ),
                            'table': Style(
                              width: Width.auto(),
                              margin: Margins.only(bottom: 8),
                              border: Border.all(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.12),
                              ),
                            ),
                            'th': Style(
                              padding: HtmlPaddings.all(6),
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .surface
                                  .withValues(alpha: 0.5),
                            ),
                            'td': Style(
                              padding: HtmlPaddings.all(6),
                              border: Border.all(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.08),
                              ),
                            ),
                            'div': Style(
                              color:
                                  Theme.of(context).colorScheme.onSurface,
                            ),
                            'span': Style(
                              color:
                                  Theme.of(context).colorScheme.onSurface,
                            ),
                            'ul': Style(
                              margin: Margins.only(bottom: 8),
                              padding: HtmlPaddings.only(left: 16),
                            ),
                            'ol': Style(
                              margin: Margins.only(bottom: 8),
                              padding: HtmlPaddings.only(left: 16),
                            ),
                            'li': Style(
                              margin: Margins.only(bottom: 4),
                              color:
                                  Theme.of(context).colorScheme.onSurface,
                            ),
                            'pre': Style(
                              padding: HtmlPaddings.all(8),
                              margin: Margins.only(bottom: 8),
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .surface
                                  .withValues(alpha: 0.5),
                            ),
                            'code': Style(
                              fontFamily: 'SF Mono',
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .surface
                                  .withValues(alpha: 0.5),
                            ),
                            'hr': Style(
                              margin: Margins.symmetric(vertical: 12),
                              border: Border(
                                top: BorderSide(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.12),
                                ),
                              ),
                            ),
                            'blockquote': Style(
                              margin: Margins.symmetric(vertical: 8),
                              padding: HtmlPaddings.only(left: 12),
                              border: Border(
                                left: BorderSide(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.18),
                                  width: 2,
                                ),
                              ),
                            ),
                            'a': Style(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          },
                        )
                      : Text(
                          bodyText,
                          style: Theme.of(context).textTheme.bodyLarge,
                        );
                  final content = ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: boundedWidth ? constraints.maxWidth : 0,
                      maxWidth:
                          boundedWidth ? constraints.maxWidth : double.infinity,
                    ),
                    child: htmlWidget,
                  );

                  if (!shouldClamp) {
                    return content;
                  }

                  return Stack(
                    children: [
                      ClipRect(
                        child: SizedBox(
                          height: _collapsedHeight(context),
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: content,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: context.space(8),
                            vertical: context.space(4),
                          ),
                          decoration: BoxDecoration(
                            color: ColorTokens.cardFill(context, 0.12),
                            borderRadius:
                                BorderRadius.circular(context.radius(999)),
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
                                color: widget.accent.withValues(alpha: 0.9),
                              ),
                              SizedBox(width: context.space(4)),
                              Text(
                                'Show more',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color:
                                          widget.accent.withValues(alpha: 0.9),
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0,
                                    ),
                              ),
                            ],
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

class ComposeBar extends StatelessWidget {
  const ComposeBar({
    super.key,
    required this.accent,
    required this.provider,
    required this.thread,
    required this.currentUserEmail,
  });

  final Color accent;
  final EmailProvider provider;
  final EmailThread thread;
  final String currentUserEmail;

  @override
  Widget build(BuildContext context) {
    return InlineReplyComposer(
      accent: accent,
      provider: provider,
      thread: thread,
      currentUserEmail: currentUserEmail,
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
    return Scaffold(
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}
