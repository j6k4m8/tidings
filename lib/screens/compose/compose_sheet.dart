import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../../models/email_models.dart';
import '../../providers/email_provider.dart';
import '../../theme/glass.dart';
import 'compose_editor.dart';
import '../../widgets/tidings_background.dart';
import 'compose_utils.dart';

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
        allowPopOut: true,
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
          allowPopOut: false,
        ),
      ),
    ),
  );
}

Future<void> showComposeWindow(
  BuildContext context, {
  required EmailProvider provider,
  required Color accent,
  EmailThread? thread,
  String? currentUserEmail,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => _ComposeScreen(
        provider: provider,
        accent: accent,
        thread: thread,
        currentUserEmail: currentUserEmail,
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
    required this.allowPopOut,
  });

  final EmailProvider provider;
  final Color accent;
  final EmailThread? thread;
  final String? currentUserEmail;
  final bool isSheet;
  final bool allowPopOut;

  @override
  State<ComposeSheet> createState() => _ComposeSheetState();
}

class _ComposeSheetState extends State<ComposeSheet> {
  late final QuillController _controller;
  final TextEditingController _toController = TextEditingController();
  final TextEditingController _ccController = TextEditingController();
  final TextEditingController _bccController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  bool _isSending = false;
  bool _isSaving = false;
  String? _sendError;
  String? _draftError;

  @override
  void initState() {
    super.initState();
    _controller = QuillController.basic();
    if (widget.thread != null) {
      _subjectController.text = replySubject(widget.thread!.subject);
      _toController.text = replyRecipients(
        widget.thread!.participants,
        widget.currentUserEmail,
      );
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
    if (_isSending || _isSaving) {
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
      _draftError = null;
    });

    final subject = _subjectController.text.trim().isEmpty
        ? '(No subject)'
        : _subjectController.text.trim();
    final to = _toController.text.trim();
    final cc = _ccController.text.trim();
    final bcc = _bccController.text.trim();

    try {
      await widget.provider.sendMessage(
        thread: widget.thread,
        toLine: to,
        ccLine: cc,
        bccLine: bcc,
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

  Future<void> _saveDraft() async {
    if (_isSending || _isSaving) {
      return;
    }
    setState(() {
      _isSaving = true;
      _sendError = null;
      _draftError = null;
    });

    final subject = _subjectController.text.trim();
    final to = _toController.text.trim();
    final cc = _ccController.text.trim();
    final bcc = _bccController.text.trim();
    final delta = _controller.document.toDelta();
    final html = deltaToHtml(delta);
    final plain = _controller.document.toPlainText();

    try {
      await widget.provider.saveDraft(
        thread: widget.thread,
        toLine: to,
        ccLine: cc,
        bccLine: bcc,
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
          SnackBar(content: Text('Save draft failed: $error')),
        );
        setState(() {
          _draftError = error.toString();
        });
      }
    }

    if (mounted) {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _popOut() async {
    if (!widget.allowPopOut) {
      return;
    }
    Navigator.of(context).pop();
    await showComposeWindow(
      context,
      provider: widget.provider,
      accent: widget.accent,
      thread: widget.thread,
      currentUserEmail: widget.currentUserEmail,
    );
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets;
    final isReply = widget.thread != null;
    final errorText = _sendError ?? _draftError;
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
                  TextButton(
                    onPressed: _isSaving ? null : _saveDraft,
                    child: Text(
                      _isSaving ? 'Saving...' : 'Close & Save Draft',
                    ),
                  ),
                  if (widget.allowPopOut)
                    IconButton(
                      onPressed: _popOut,
                      icon: const Icon(Icons.open_in_new_rounded),
                      tooltip: 'Pop out',
                    ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Close',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ComposeEditor(
                controller: _controller,
                toController: _toController,
                ccController: _ccController,
                bccController: _bccController,
                subjectController: _subjectController,
                showFields: true,
                placeholder: 'Write something beautiful...',
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
              if (errorText != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      _sendError != null ? 'Send error' : 'Draft error',
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
        ),
      ),
    );
  }
}

class _ComposeScreen extends StatelessWidget {
  const _ComposeScreen({
    required this.provider,
    required this.accent,
    this.thread,
    this.currentUserEmail,
  });

  final EmailProvider provider;
  final Color accent;
  final EmailThread? thread;
  final String? currentUserEmail;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: TidingsBackground(
        accent: accent,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ComposeSheet(
                  provider: provider,
                  accent: accent,
                  thread: thread,
                  currentUserEmail: currentUserEmail,
                  isSheet: false,
                  allowPopOut: false,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
