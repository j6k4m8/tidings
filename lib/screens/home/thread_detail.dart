import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/email_models.dart';
import '../../providers/email_provider.dart';
import '../../state/tidings_settings.dart';
import '../../theme/account_accent.dart';
import '../../theme/color_tokens.dart';
import '../../theme/glass.dart';
import '../../widgets/tidings_background.dart';
import '../compose/compose_sheet.dart';
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
            isCompact ? context.space(16) : context.space(22),
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
                      style: Theme.of(context).textTheme.headlineSmall,
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
              SizedBox(height: context.space(6)),
              Text(
                thread.participantSummary,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              SizedBox(height: context.space(16)),
              Expanded(
                child: ProviderBody(
                  status: provider.status,
                  errorMessage: provider.errorMessage,
                  onRetry: provider.refresh,
                  isEmpty: messages.isEmpty,
                  emptyMessage: 'No messages in this thread.',
                  child: ListView.separated(
                    itemCount: messages.length,
                    separatorBuilder: (_, _) =>
                        SizedBox(height: context.space(12)),
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
                        initiallyExpanded: shouldExpand,
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
    required this.initiallyExpanded,
  });

  final EmailMessage message;
  final Color accent;
  final bool initiallyExpanded;

  @override
  State<MessageCard> createState() => _MessageCardState();
}

class _MessageCardState extends State<MessageCard> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  void didUpdateWidget(covariant MessageCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message.id != widget.message.id) {
      _expanded = widget.initiallyExpanded;
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final showSubject = !context.tidingsSettings.hideThreadSubjects;
    final cardColor = widget.message.isMe
        ? widget.accent.withValues(alpha: 0.18)
        : ColorTokens.cardFill(context, 0.08);

    return GestureDetector(
      onTap: _toggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.all(context.space(14)),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(context.radius(18)),
          border: Border.all(color: ColorTokens.border(context, 0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  widget.message.from.displayName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                SizedBox(width: context.space(8)),
                Text(
                  widget.message.time,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const Spacer(),
                Icon(
                  Icons.more_horiz_rounded,
                  color: scheme.onSurface.withValues(alpha: 0.5),
                ),
              ],
            ),
            SizedBox(height: context.space(8)),
            if (showSubject) ...[
              Text(
                widget.message.subject,
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: context.space(8)),
            ],
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) =>
                  FadeTransition(opacity: animation, child: child),
              child: _expanded && widget.message.bodyHtml != null
                  ? LayoutBuilder(
                      key: const ValueKey('html-body'),
                      builder: (context, constraints) {
                        final boundedWidth = constraints.maxWidth.isFinite;
                        return ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth: boundedWidth ? constraints.maxWidth : 0,
                            maxWidth: boundedWidth
                                ? constraints.maxWidth
                                : double.infinity,
                          ),
                          child: Html(
                            data: widget.message.bodyHtml,
                            shrinkWrap: true,
                            onLinkTap: (url, attributes, element) =>
                                _handleLinkTap(url),
                            style: {
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
                              ),
                              'p': Style(margin: Margins.only(bottom: 8)),
                              'a': Style(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            },
                          ),
                        );
                      },
                    )
                  : Text(
                      widget.message.bodyPlainText,
                      key: const ValueKey('text-body'),
                      maxLines: _expanded ? null : 3,
                      overflow: _expanded ? null : TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyLarge,
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
    final tokens = accentTokensFor(context, accent);
    return GlassPanel(
      borderRadius: BorderRadius.circular(context.radius(20)),
      padding: EdgeInsets.all(context.space(12)),
      variant: GlassVariant.sheet,
      child: Row(
        children: [
          Icon(Icons.reply_rounded, color: tokens.onSurface),
          SizedBox(width: context.space(10)),
          Expanded(
            child: Text(
              'Reply with rich formatting',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          FilledButton(
            onPressed: () => showComposeSheet(
              context,
              provider: provider,
              accent: accent,
              thread: thread,
              currentUserEmail: currentUserEmail,
            ),
            child: const Text('Reply'),
          ),
        ],
      ),
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
