import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:flutter/services.dart';

import '../../models/email_models.dart';
import '../../providers/email_provider.dart';
import '../../theme/glass.dart';

Future<void> showComposeSheet(
  BuildContext context, {
  required EmailProvider provider,
  required Color accent,
  EmailThread? thread,
  String? currentUserEmail,
}) {
  final isCompact = MediaQuery.of(context).size.width < 720;
  if (isCompact) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ComposeSheet(
        provider: provider,
        accent: accent,
        thread: thread,
        currentUserEmail: currentUserEmail,
        isSheet: true,
      ),
    );
  }
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: ComposeSheet(
          provider: provider,
          accent: accent,
          thread: thread,
          currentUserEmail: currentUserEmail,
          isSheet: false,
        ),
      ),
    ),
  );
}

class ComposeSheet extends StatefulWidget {
  const ComposeSheet({
    super.key,
    required this.provider,
    required this.accent,
    this.thread,
    this.currentUserEmail,
    required this.isSheet,
  });

  final EmailProvider provider;
  final Color accent;
  final EmailThread? thread;
  final String? currentUserEmail;
  final bool isSheet;

  @override
  State<ComposeSheet> createState() => _ComposeSheetState();
}

class _ComposeSheetState extends State<ComposeSheet> {
  late final QuillController _controller;
  final TextEditingController _toController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  bool _showToolbar = false;
  bool _isSending = false;
  String? _sendError;

  @override
  void initState() {
    super.initState();
    _controller = QuillController.basic();
    if (widget.thread != null) {
      _subjectController.text = _replySubject(widget.thread!.subject);
      _toController.text = _replyRecipients(
        widget.thread!.participants,
        widget.currentUserEmail,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _toController.dispose();
    _subjectController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_isSending) {
      return;
    }
    final delta = _controller.document.toDelta();
    final html = _deltaToHtml(delta);
    final plain = _controller.document.toPlainText().trim();

    if (plain.isEmpty) {
      return;
    }

    setState(() {
      _isSending = true;
      _sendError = null;
    });

    final subject = _subjectController.text.trim().isEmpty
        ? '(No subject)'
        : _subjectController.text.trim();
    final to = _toController.text.trim();

    try {
      await widget.provider.sendMessage(
        thread: widget.thread,
        toLine: to,
        subject: subject,
        bodyHtml: html,
        bodyText: plain,
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Send failed: $error')),
        );
        setState(() {
          _sendError = error.toString();
        });
      }
    }

    if (mounted) {
      setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets;
    final isReply = widget.thread != null;
    final padding = widget.isSheet
        ? EdgeInsets.fromLTRB(16, 16, 16, 16 + insets.bottom)
        : EdgeInsets.only(bottom: insets.bottom);
    return SafeArea(
      child: Padding(
        padding: padding,
        child: GlassPanel(
          borderRadius: BorderRadius.circular(24),
          padding: const EdgeInsets.all(16),
          variant: GlassVariant.sheet,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    isReply ? 'Reply' : 'Compose',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () =>
                        setState(() => _showToolbar = !_showToolbar),
                    icon: Icon(
                      _showToolbar
                          ? Icons.close_fullscreen_rounded
                          : Icons.text_format_rounded,
                    ),
                    tooltip: _showToolbar ? 'Hide formatting' : 'Show formatting',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _toController,
                decoration: const InputDecoration(
                  labelText: 'To',
                  hintText: 'name@example.com',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _subjectController,
                decoration: const InputDecoration(
                  labelText: 'Subject',
                ),
              ),
              const SizedBox(height: 12),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _showToolbar
                    ? QuillSimpleToolbar(
                        controller: _controller,
                        config: const QuillSimpleToolbarConfig(
                          showUndo: false,
                          showRedo: false,
                          showFontFamily: false,
                          showFontSize: false,
                          showColorButton: false,
                          showBackgroundColorButton: false,
                          showSearchButton: false,
                          showSubscript: false,
                          showSuperscript: false,
                          showCodeBlock: false,
                          showQuote: false,
                          showIndent: false,
                          showListNumbers: false,
                          showListBullets: false,
                          showListCheck: false,
                          showInlineCode: false,
                          showHeaderStyle: false,
                          showClearFormat: false,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 160, maxHeight: 320),
                child: QuillEditor.basic(
                  controller: _controller,
                  config: const QuillEditorConfig(
                    placeholder: 'Write something beautiful...',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _isSending ? null : _send,
                    icon: const Icon(Icons.send_rounded),
                    label: Text(_isSending
                        ? 'Sending...'
                        : (_sendError == null ? 'Send' : 'Retry')),
                  ),
                ],
              ),
              if (_sendError != null) ...[
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: _sendError!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Error copied.')),
                    );
                  },
                  child: Text(
                    _sendError!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.redAccent,
                        ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _replySubject(String subject) {
  final trimmed = subject.trim();
  if (trimmed.toLowerCase().startsWith('re:')) {
    return trimmed;
  }
  return trimmed.isEmpty ? 'Re:' : 'Re: $trimmed';
}

String _replyRecipients(
  List<EmailAddress> participants,
  String? currentUserEmail,
) {
  final filtered = currentUserEmail == null
      ? participants
      : participants
          .where((participant) => participant.email != currentUserEmail)
          .toList();
  final list = filtered.isEmpty ? participants : filtered;
  return list.map((participant) => participant.email).join(', ');
}

String _deltaToHtml(Delta delta) {
  final buffer = StringBuffer();
  var lineBuffer = StringBuffer();
  for (final op in delta.toList()) {
    final data = op.data;
    final attrs = op.attributes ?? <String, dynamic>{};
    if (data is! String) {
      continue;
    }
    var text = data;
    while (text.contains('\n')) {
      final index = text.indexOf('\n');
      final segment = text.substring(0, index);
      lineBuffer.write(_wrapInline(segment, attrs));
      buffer.write('<p>${lineBuffer.toString().trim()}</p>');
      lineBuffer = StringBuffer();
      text = text.substring(index + 1);
    }
    if (text.isNotEmpty) {
      lineBuffer.write(_wrapInline(text, attrs));
    }
  }
  final remainder = lineBuffer.toString().trim();
  if (remainder.isNotEmpty) {
    buffer.write('<p>$remainder</p>');
  }
  return buffer.toString();
}

String _wrapInline(String text, Map<String, dynamic> attrs) {
  var result = text;
  if (attrs['bold'] == true) {
    result = '<strong>$result</strong>';
  }
  if (attrs['italic'] == true) {
    result = '<em>$result</em>';
  }
  if (attrs['underline'] == true) {
    result = '<u>$result</u>';
  }
  return result;
}
