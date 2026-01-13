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

  @override
  void initState() {
    super.initState();
    _controller = QuillController.basic();
    _subjectController.text = replySubject(widget.thread.subject);
    _toController.text = replyRecipients(
      widget.thread.participants,
      widget.currentUserEmail,
    );
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

  @override
  Widget build(BuildContext context) {
    final errorText = _sendError;
    final summary = 'To: ${_toController.text.trim()}';
    final subject =
        _subjectController.text.trim().isEmpty
            ? 'Subject: (No subject)'
            : 'Subject: ${_subjectController.text.trim()}';
    return GlassPanel(
      borderRadius: BorderRadius.circular(context.radius(20)),
      padding: EdgeInsets.all(context.space(12)),
      variant: GlassVariant.sheet,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.reply_rounded, color: widget.accent),
              SizedBox(width: context.space(8)),
              Text(
                'Reply',
                style: Theme.of(context).textTheme.titleMedium,
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
            recipientSummary: summary,
            subjectSummary: subject,
            placeholder: 'Write a reply...',
            minEditorHeight: 120,
            maxEditorHeight: 260,
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
