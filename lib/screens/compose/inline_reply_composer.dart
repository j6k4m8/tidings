import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../../models/email_models.dart';
import '../../providers/email_provider.dart';
import '../../theme/color_tokens.dart';
import '../../theme/glass.dart';
import '../../state/tidings_settings.dart';
import 'compose_editor.dart';
import 'compose_form.dart';
import 'compose_sheet.dart';
import 'compose_utils.dart';

class InlineReplyController {
  ReplyMode? _pendingMode;
  bool _pendingFocus = false;
  String? _pendingThreadId;
  String? _attachedThreadId;
  void Function(ReplyMode mode)? _setMode;
  VoidCallback? _focusEditor;
  Future<void> Function()? _send;

  void attach({
    required String threadId,
    required void Function(ReplyMode mode) setMode,
    required VoidCallback focusEditor,
    required Future<void> Function() send,
  }) {
    _attachedThreadId = threadId;
    _setMode = setMode;
    _focusEditor = focusEditor;
    _send = send;
    if (_pendingMode != null && _pendingThreadId == threadId) {
      _setMode?.call(_pendingMode!);
      _pendingMode = null;
    }
    if (_pendingFocus && _pendingThreadId == threadId) {
      _focusEditor?.call();
      _pendingFocus = false;
    }
  }

  void detach(String threadId) {
    if (_attachedThreadId != threadId) {
      return;
    }
    _attachedThreadId = null;
    _setMode = null;
    _focusEditor = null;
    _send = null;
  }

  void setModeForThread(String threadId, ReplyMode mode) {
    if (_setMode == null || _attachedThreadId != threadId) {
      _pendingThreadId = threadId;
      _pendingMode = mode;
      return;
    }
    _setMode?.call(mode);
  }

  void focusEditorForThread(String threadId) {
    if (_focusEditor == null || _attachedThreadId != threadId) {
      _pendingThreadId = threadId;
      _pendingFocus = true;
      return;
    }
    _focusEditor?.call();
  }

  Future<void> send() async {
    await _send?.call();
  }
}

class InlineReplyComposer extends StatefulWidget {
  const InlineReplyComposer({
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
  State<InlineReplyComposer> createState() => _InlineReplyComposerState();
}

class _InlineReplyComposerState extends State<InlineReplyComposer> {
  static final _escapeKey =
      LogicalKeySet(LogicalKeyboardKey.escape);
  late final QuillController _controller;
  final FocusNode _editorFocusNode = FocusNode();
  final TextEditingController _toController = TextEditingController();
  final TextEditingController _ccController = TextEditingController();
  final TextEditingController _bccController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  bool _showDetails = false;
  bool _isSending = false;
  String? _sendError;
  ReplyMode _replyMode = ReplyMode.reply;

  @override
  void initState() {
    super.initState();
    _controller = QuillController.basic();
    _applyMode(_replyMode);
    widget.controller?.attach(
      threadId: widget.thread.id,
      setMode: _setReplyMode,
      focusEditor: _focusEditor,
      send: _send,
    );
  }

  @override
  void didUpdateWidget(covariant InlineReplyComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.thread.id != widget.thread.id) {
      _applyMode(_replyMode);
    }
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.detach(oldWidget.thread.id);
      widget.controller?.attach(
        threadId: widget.thread.id,
        setMode: _setReplyMode,
        focusEditor: _focusEditor,
        send: _send,
      );
    } else if (oldWidget.thread.id != widget.thread.id) {
      widget.controller?.attach(
        threadId: widget.thread.id,
        setMode: _setReplyMode,
        focusEditor: _focusEditor,
        send: _send,
      );
    }
  }

  void _setReplyMode(ReplyMode mode) {
    setState(() {
      _replyMode = mode;
      _applyMode(mode);
    });
    _focusEditor();
  }

  void _applyMode(ReplyMode mode) {
    final latest = widget.provider.latestMessageForThread(widget.thread.id);
    if (mode == ReplyMode.forward) {
      _subjectController.text = _forwardSubject(widget.thread.subject);
      _toController.text = '';
      _showDetails = true;
    } else if (mode == ReplyMode.replyAll) {
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
    _editorFocusNode.dispose();
    _toController.dispose();
    _ccController.dispose();
    _bccController.dispose();
    _subjectController.dispose();
    widget.controller?.detach(widget.thread.id);
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
    if (_replyMode == ReplyMode.forward) {
      return 'someone';
    }
    if (_replyMode == ReplyMode.replyAll) {
      return _replyAllTargetLabel();
    }
    return name;
  }

  List<String> _replyAllNames() {
    final names = <String>[];
    final seen = <String>{};
    for (final participant in widget.thread.participants) {
      if (participant.email == widget.currentUserEmail) {
        continue;
      }
      final name = participant.normalizedDisplayName.trim();
      if (name.isNotEmpty && !seen.contains(name)) {
        seen.add(name);
        names.add(name);
      }
    }
    return names;
  }

  String _replyAllTargetLabel() {
    final names = _replyAllNames();
    if (names.isEmpty) {
      return 'thread';
    }
    if (names.length == 1) {
      return names.first;
    }
    if (names.length == 2) {
      return '${names[0]} and ${names[1]}';
    }
    if (names.length == 3) {
      return '${names[0]}, ${names[1]}, and ${names[2]}';
    }
    final others = names.length - 2;
    return '${names[0]}, ${names[1]}, and $others others';
  }

  String _replyLabel() {
    if (_replyMode == ReplyMode.forward) {
      return 'Forward';
    }
    if (_replyMode == ReplyMode.replyAll) {
      return 'Reply all to ${_replyAllTargetLabel()}';
    }
    return 'Reply to ${_replyTargetLabel()}';
  }

  String _placeholderForMode() {
    switch (_replyMode) {
      case ReplyMode.reply:
        return 'Reply';
      case ReplyMode.replyAll:
        return 'Reply All';
      case ReplyMode.forward:
        return 'Forward';
    }
  }

  void _focusEditor() {
    void attempt(int remaining) {
      if (!mounted) {
        return;
      }
      FocusScope.of(context).requestFocus(_editorFocusNode);
      if (_editorFocusNode.hasFocus || remaining <= 0) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        attempt(remaining - 1);
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      attempt(2);
    });
  }

  @override
  Widget build(BuildContext context) {
    final errorText = _sendError;
    final collapsedHeight = context.space(42);
    final expandedMinHeight = context.space(140);
    final replyLabel = _replyLabel();
    final placeholder = _placeholderForMode();
    return Shortcuts(
      shortcuts: {_escapeKey: const _EscapeIntent()},
      child: Actions(
        actions: {
          _EscapeIntent: CallbackAction<_EscapeIntent>(
            onInvoke: (intent) {
              if (_editorFocusNode.hasFocus) {
                _editorFocusNode.unfocus();
              } else {
                FocusManager.instance.primaryFocus?.unfocus();
              }
              widget.parentFocusNode?.requestFocus();
              return null;
            },
          ),
        },
        child: Container(
          padding: EdgeInsets.all(context.space(12)),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(context.radius(20)),
            border: Border.all(color: ColorTokens.border(context, 0.18)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!_showDetails) ...[
                Row(
                  children: [
                    PopupMenuButton<ReplyMode>(
                      tooltip: 'Reply options',
                      onSelected: (mode) {
                        _setReplyMode(mode);
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: ReplyMode.reply,
                          child: Text('Reply'),
                        ),
                        PopupMenuItem(
                          value: ReplyMode.replyAll,
                          child: Text('Reply all'),
                        ),
                        PopupMenuItem(
                          value: ReplyMode.forward,
                          child: Text('Forward'),
                        ),
                      ],
                      child: Row(
                        children: [
                          Icon(
                            Icons.reply_rounded,
                            color: widget.accent,
                            size: 16,
                          ),
                          SizedBox(width: context.space(8)),
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: context.space(200),
                            ),
                            child: Text(
                              replyLabel,
                              style: Theme.of(context).textTheme.bodySmall,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Expand',
                      onPressed: () {
                        setState(() {
                          _showDetails = true;
                        });
                      },
                      icon: const Icon(Icons.unfold_more_rounded),
                    ),
                  ],
                ),
                SizedBox(height: context.space(8)),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(context.radius(16)),
                          border: Border.all(
                            color: ColorTokens.border(context, 0.14),
                          ),
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: context.space(8),
                          vertical: context.space(4),
                        ),
                        child: ComposeEditor(
                          controller: _controller,
                          toController: _toController,
                          ccController: _ccController,
                          bccController: _bccController,
                          subjectController: _subjectController,
                          showFields: false,
                          showFormattingToggle: false,
                          placeholder: placeholder,
                          minEditorHeight: collapsedHeight,
                          maxEditorHeight: collapsedHeight,
                          editorFocusNode: _editorFocusNode,
                          onEscape: () {
                            widget.parentFocusNode?.requestFocus();
                          },
                        ),
                      ),
                    ),
                    SizedBox(width: context.space(8)),
                    GlassPanel(
                      borderRadius:
                          BorderRadius.circular(context.radius(16)),
                      padding: EdgeInsets.all(context.space(4)),
                      variant: GlassVariant.pill,
                      accent: widget.accent,
                      selected: true,
                      child: IconButton(
                        onPressed: _isSending ? null : _send,
                        icon: const Icon(Icons.send_rounded, size: 16),
                        tooltip: _isSending
                            ? 'Sending...'
                            : (_sendError == null ? 'Send' : 'Retry'),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Row(
                  children: [
                    PopupMenuButton<ReplyMode>(
                      tooltip: 'Reply options',
                      onSelected: (mode) {
                        _setReplyMode(mode);
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: ReplyMode.reply,
                          child: Text('Reply'),
                        ),
                        PopupMenuItem(
                          value: ReplyMode.replyAll,
                          child: Text('Reply all'),
                        ),
                        PopupMenuItem(
                          value: ReplyMode.forward,
                          child: Text('Forward'),
                        ),
                      ],
                      child: Row(
                        children: [
                          Icon(
                            Icons.reply_rounded,
                            color: widget.accent,
                            size: 16,
                          ),
                          SizedBox(width: context.space(8)),
                          Text(
                            replyLabel,
                            style: Theme.of(context).textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Pop out',
                      onPressed: () {
                        showComposeSheet(
                          context,
                          provider: widget.provider,
                          accent: widget.accent,
                          thread: widget.thread,
                          currentUserEmail: widget.currentUserEmail,
                          initialTo: _toController.text,
                          initialCc: _ccController.text,
                          initialBcc: _bccController.text,
                          initialSubject: _subjectController.text,
                          initialDelta: _controller.document.toDelta(),
                        );
                      },
                      icon: const Icon(Icons.open_in_new_rounded),
                    ),
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
                ComposeForm(
                  controller: _controller,
                  toController: _toController,
                  ccController: _ccController,
                  bccController: _bccController,
                  subjectController: _subjectController,
                  showFields: _showDetails,
                  showFormattingToggle: _showDetails,
                  placeholder: placeholder,
                  minEditorHeight: expandedMinHeight,
                  maxEditorHeight: context.space(260),
                  editorFocusNode: _editorFocusNode,
                  showEditorBorder: true,
                  onEscape: () {
                    widget.parentFocusNode?.requestFocus();
                  },
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
                ),
              ],
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
        ),
      ),
    );
  }
}

class _EscapeIntent extends Intent {
  const _EscapeIntent();
}

enum ReplyMode {
  reply,
  replyAll,
  forward,
}

extension ReplyModeMeta on ReplyMode {
  String get label {
    switch (this) {
      case ReplyMode.reply:
        return 'Reply';
      case ReplyMode.replyAll:
        return 'Reply all';
      case ReplyMode.forward:
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
