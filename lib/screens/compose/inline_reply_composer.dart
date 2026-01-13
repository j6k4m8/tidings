import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../../models/email_models.dart';
import '../../providers/email_provider.dart';
import '../../theme/glass.dart';
import '../../state/tidings_settings.dart';
import 'compose_editor.dart';
import 'compose_utils.dart';

class InlineReplyComposer extends StatefulWidget {
  const InlineReplyComposer({
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
  State<InlineReplyComposer> createState() => _InlineReplyComposerState();
}

class _InlineReplyComposerState extends State<InlineReplyComposer> {
  late final QuillController _controller;
  final TextEditingController _toController = TextEditingController();
  final TextEditingController _ccController = TextEditingController();
  final TextEditingController _bccController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  bool _showDetails = false;
  bool _isSending = false;
  String? _sendError;
  _ReplyMode _replyMode = _ReplyMode.reply;

  @override
  void initState() {
    super.initState();
    _controller = QuillController.basic();
    _applyMode(_replyMode);
  }

  @override
  void didUpdateWidget(covariant InlineReplyComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.thread.id != widget.thread.id) {
      _applyMode(_replyMode);
    }
  }

  void _applyMode(_ReplyMode mode) {
    final latest = widget.provider.latestMessageForThread(widget.thread.id);
    if (mode == _ReplyMode.forward) {
      _subjectController.text = _forwardSubject(widget.thread.subject);
      _toController.text = '';
      _showDetails = true;
    } else if (mode == _ReplyMode.replyAll) {
      _subjectController.text = replySubject(widget.thread.subject);
      _toController.text = replyRecipients(
        widget.thread.participants,
        widget.currentUserEmail,
      );
    } else {
      _subjectController.text = replySubject(widget.thread.subject);
      _toController.text = latest?.from.email ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _toController.dispose();
    _ccController.dispose();
    _bccController.dispose();
    _subjectController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_isSending) {
      return;
    }
    final delta = _controller.document.toDelta();
    final html = deltaToHtml(delta);
    final plain = _controller.document.toPlainText().trim();
    if (plain.isEmpty) {
      return;
    }
    setState(() {
      _isSending = true;
      _sendError = null;
    });
    try {
      await widget.provider.sendMessage(
        thread: widget.thread,
        toLine: _toController.text.trim(),
        ccLine: _ccController.text.trim(),
        bccLine: _bccController.text.trim(),
        subject: _subjectController.text.trim().isEmpty
            ? '(No subject)'
            : _subjectController.text.trim(),
        bodyHtml: html,
        bodyText: plain,
      );
      _controller.clear();
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

  String _replyTargetLabel() {
    final latest = widget.provider.latestMessageForThread(widget.thread.id);
    final sender = latest?.from;
    final name = sender?.displayName ?? sender?.email ?? 'thread';
    if (_replyMode == _ReplyMode.forward) {
      return 'someone';
    }
    return name;
  }

  @override
  Widget build(BuildContext context) {
    final errorText = _sendError;
    final summary = 'To: ${_toController.text.trim()}';
    final subject =
        _subjectController.text.trim().isEmpty
            ? 'Subject: (No subject)'
            : 'Subject: ${_subjectController.text.trim()}';
    final collapsedHeight = context.space(44);
    final expandedMinHeight = context.space(140);
    return GlassPanel(
      borderRadius: BorderRadius.circular(context.radius(20)),
      padding: EdgeInsets.all(context.space(12)),
      variant: GlassVariant.sheet,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PopupMenuButton<_ReplyMode>(
                tooltip: 'Reply options',
                onSelected: (mode) {
                  setState(() {
                    _replyMode = mode;
                    _applyMode(mode);
                  });
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: _ReplyMode.reply,
                    child: Text('Reply'),
                  ),
                  PopupMenuItem(
                    value: _ReplyMode.replyAll,
                    child: Text('Reply all'),
                  ),
                  PopupMenuItem(
                    value: _ReplyMode.forward,
                    child: Text('Forward'),
                  ),
                ],
                child: Row(
                  children: [
                    Icon(Icons.reply_rounded,
                        color: widget.accent, size: 16),
                    SizedBox(width: context.space(8)),
                    Text(
                      '${_replyMode.label} to ${_replyTargetLabel()}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _showDetails = !_showDetails;
                  });
                },
                icon: Icon(
                  _showDetails
                      ? Icons.unfold_less_rounded
                      : Icons.unfold_more_rounded,
                ),
                label: Text(_showDetails ? 'Collapse' : 'Expand'),
              ),
            ],
          ),
          SizedBox(height: context.space(8)),
          ComposeEditor(
            controller: _controller,
            toController: _toController,
            ccController: _ccController,
            bccController: _bccController,
            subjectController: _subjectController,
            showFields: _showDetails,
            showFormattingToggle: _showDetails,
            recipientSummary: _showDetails ? summary : null,
            subjectSummary: _showDetails ? subject : null,
            placeholder: 'Write a reply...',
            minEditorHeight:
                _showDetails ? expandedMinHeight : collapsedHeight,
            maxEditorHeight:
                _showDetails ? context.space(260) : collapsedHeight,
          ),
          SizedBox(height: context.space(12)),
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
          if (errorText != null) ...[
            SizedBox(height: context.space(8)),
            Row(
              children: [
                Text(
                  'Send error',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Colors.redAccent,
                      ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: errorText));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Error copied.')),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  tooltip: 'Copy error',
                ),
              ],
            ),
            SelectableText(
              errorText,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.redAccent,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

enum _ReplyMode {
  reply,
  replyAll,
  forward,
}

extension on _ReplyMode {
  String get label {
    switch (this) {
      case _ReplyMode.reply:
        return 'Reply';
      case _ReplyMode.replyAll:
        return 'Reply all';
      case _ReplyMode.forward:
        return 'Forward';
    }
  }
}

String _forwardSubject(String subject) {
  final trimmed = subject.trim();
  if (trimmed.toLowerCase().startsWith('fwd:') ||
      trimmed.toLowerCase().startsWith('fw:')) {
    return trimmed;
  }
  return trimmed.isEmpty ? 'Fwd:' : 'Fwd: $trimmed';
}
