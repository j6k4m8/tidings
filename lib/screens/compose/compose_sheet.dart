import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';

import '../../models/email_models.dart';
import '../../providers/email_provider.dart';
import 'compose_form.dart';
import '../../widgets/tidings_background.dart';
import '../../widgets/paper_panel.dart';
import 'compose_utils.dart';

Future<void> showComposeSheet(
  BuildContext context, {
  required EmailProvider provider,
  required Color accent,
  EmailThread? thread,
  String? currentUserEmail,
  String? initialTo,
  String? initialCc,
  String? initialBcc,
  String? initialSubject,
  Delta? initialDelta,
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
        initialTo: initialTo,
        initialCc: initialCc,
        initialBcc: initialBcc,
        initialSubject: initialSubject,
        initialDelta: initialDelta,
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
          initialTo: initialTo,
          initialCc: initialCc,
          initialBcc: initialBcc,
          initialSubject: initialSubject,
          initialDelta: initialDelta,
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
  String? initialTo,
  String? initialCc,
  String? initialBcc,
  String? initialSubject,
  Delta? initialDelta,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => _ComposeScreen(
        provider: provider,
        accent: accent,
        thread: thread,
        currentUserEmail: currentUserEmail,
        initialTo: initialTo,
        initialCc: initialCc,
        initialBcc: initialBcc,
        initialSubject: initialSubject,
        initialDelta: initialDelta,
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
    this.initialTo,
    this.initialCc,
    this.initialBcc,
    this.initialSubject,
    this.initialDelta,
    required this.isSheet,
    required this.allowPopOut,
  });

  final EmailProvider provider;
  final Color accent;
  final EmailThread? thread;
  final String? currentUserEmail;
  final String? initialTo;
  final String? initialCc;
  final String? initialBcc;
  final String? initialSubject;
  final Delta? initialDelta;
  final bool isSheet;
  final bool allowPopOut;

  @override
  State<ComposeSheet> createState() => _ComposeSheetState();
}

class _ComposeSheetState extends State<ComposeSheet> {
  late final QuillController _controller;
  final FocusNode _toFocusNode = FocusNode(debugLabel: 'ComposeTo');
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
    if (widget.initialDelta != null) {
      final document = Document.fromDelta(widget.initialDelta!);
      _controller = QuillController(
        document: document,
        selection: TextSelection.collapsed(offset: document.length),
      );
    } else {
      _controller = QuillController.basic();
    }
    if (widget.initialSubject != null) {
      _subjectController.text = widget.initialSubject!;
    } else if (widget.thread != null) {
      _subjectController.text = replySubject(widget.thread!.subject);
    }
    if (widget.initialTo != null) {
      _toController.text = widget.initialTo!;
    } else if (widget.thread != null) {
      _toController.text = replyRecipients(
        widget.thread!.participants,
        widget.currentUserEmail,
      );
    }
    if (widget.initialCc != null) {
      _ccController.text = widget.initialCc!;
    }
    if (widget.initialBcc != null) {
      _bccController.text = widget.initialBcc!;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _toFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _toFocusNode.dispose();
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
        // TODO: "Sent (Click to undo)" once undo-send delay is implemented.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sent')),
        );
      }
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
    final delta = _controller.document.toDelta();
    final to = _toController.text;
    final cc = _ccController.text;
    final bcc = _bccController.text;
    final subject = _subjectController.text;
    Navigator.of(context).pop();
    await showComposeWindow(
      context,
      provider: widget.provider,
      accent: widget.accent,
      thread: widget.thread,
      currentUserEmail: widget.currentUserEmail,
      initialTo: to,
      initialCc: cc,
      initialBcc: bcc,
      initialSubject: subject,
      initialDelta: delta,
    );
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets;
    final isReply = widget.thread != null;
    final errorText = _sendError ?? _draftError;
    final surface = Theme.of(context).colorScheme.surface;
    final padding = widget.isSheet
        ? EdgeInsets.fromLTRB(16, 16, 16, 16 + insets.bottom)
        : EdgeInsets.only(bottom: insets.bottom);
    return SafeArea(
      child: Padding(
        padding: padding,
        child: PaperPanel(
          borderRadius: BorderRadius.circular(24),
          padding: const EdgeInsets.all(16),
          fillColor: surface,
          elevated: true,
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
              ComposeForm(
                controller: _controller,
                toController: _toController,
                ccController: _ccController,
                bccController: _bccController,
                subjectController: _subjectController,
                toFocusNode: _toFocusNode,
                showFields: true,
                placeholder: 'Write a message...',
                footer: Row(
                  children: [
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: _isSending ? null : _send,
                      icon: const Icon(Icons.send_rounded),
                      label: Text(
                        _isSending
                            ? 'Sending...'
                            : (_sendError == null ? 'Send' : 'Retry'),
                      ),
                    ),
                  ],
                ),
                errorText: errorText,
                errorLabel: _sendError != null ? 'Send error' : 'Draft error',
                onCopyError: errorText == null
                    ? null
                    : () {
                        Clipboard.setData(ClipboardData(text: errorText));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Error copied.')),
                        );
                      },
              ),
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
    this.initialTo,
    this.initialCc,
    this.initialBcc,
    this.initialSubject,
    this.initialDelta,
  });

  final EmailProvider provider;
  final Color accent;
  final EmailThread? thread;
  final String? currentUserEmail;
  final String? initialTo;
  final String? initialCc;
  final String? initialBcc;
  final String? initialSubject;
  final Delta? initialDelta;

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
                  initialTo: initialTo,
                  initialCc: initialCc,
                  initialBcc: initialBcc,
                  initialSubject: initialSubject,
                  initialDelta: initialDelta,
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
