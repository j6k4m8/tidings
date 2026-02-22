import '../models/email_models.dart';
import 'query_ast.dart';
import 'query_date.dart';

/// Evaluates a [QueryNode] AST against email data client-side.
///
/// [messages] should be all messages for the thread being tested.
/// If [messages] is empty the evaluator works on thread-level fields only.
class QueryEvaluator {
  const QueryEvaluator({
    this.accountEmails = const [],
    this.currentFolderPath,
  });

  /// All email addresses associated with the current account (for `is:me`).
  final List<String> accountEmails;
  final String? currentFolderPath;

  bool evaluate(QueryNode node, EmailThread thread, List<EmailMessage> messages) {
    return switch (node) {
      MatchAllNode() => true,
      AndNode(:final left, :final right) =>
          evaluate(left, thread, messages) && evaluate(right, thread, messages),
      OrNode(:final left, :final right) =>
          evaluate(left, thread, messages) || evaluate(right, thread, messages),
      NotNode(:final child) => !evaluate(child, thread, messages),
      FreeTextNode(:final text) => _evalFreeText(text, thread, messages),
      FieldNode(:final field, :final value) =>
          _evalField(field, value, thread, messages),
    };
  }

  // ── Free text ─────────────────────────────────────────────────────────────

  bool _evalFreeText(String text, EmailThread thread, List<EmailMessage> messages) {
    final q = text.toLowerCase();
    if (thread.subject.toLowerCase().contains(q)) return true;
    for (final p in thread.participants) {
      if (p.displayName.toLowerCase().contains(q)) return true;
      if (p.email.toLowerCase().contains(q)) return true;
    }
    for (final m in messages) {
      if ((m.bodyPlainText).toLowerCase().contains(q)) return true;
      if (m.from.email.toLowerCase().contains(q)) return true;
      if (m.from.displayName.toLowerCase().contains(q)) return true;
      for (final r in [...m.to, ...m.cc]) {
        if (r.email.toLowerCase().contains(q)) return true;
        if (r.displayName.toLowerCase().contains(q)) return true;
      }
    }
    return false;
  }

  // ── Field matchers ────────────────────────────────────────────────────────

  bool _evalField(
    String field,
    String value,
    EmailThread thread,
    List<EmailMessage> messages,
  ) {
    return switch (field) {
      'from' => _matchesAddress(
          value, messages.map((m) => m.from).toList()),
      'to' => _matchesAddress(
          value, messages.expand((m) => m.to).toList()),
      'cc' => _matchesAddress(
          value, messages.expand((m) => m.cc).toList()),
      'bcc' => _matchesAddress(
          value, messages.expand((m) => m.bcc).toList()),
      'subject' || 'label' => thread.subject.toLowerCase().contains(value),
      'before' => _evalBefore(value, thread, messages),
      'after' => _evalAfter(value, thread, messages),
      'date' => _evalDate(value, thread, messages),
      'account' => _evalAccount(value),
      'in' => _evalIn(value, thread, messages),
      'has' => _evalHas(value, messages),
      'is' => _evalIs(value, thread, messages),
      _ => false,
    };
  }

  bool _matchesAddress(String query, List<EmailAddress> addresses) {
    final q = query.toLowerCase();
    return addresses.any(
      (a) => a.email.toLowerCase().contains(q) ||
          a.displayName.toLowerCase().contains(q),
    );
  }

  DateTime? _threadDate(EmailThread thread, List<EmailMessage> messages) {
    if (messages.isNotEmpty) {
      // Use the latest message date
      DateTime? latest;
      for (final m in messages) {
        final t = m.receivedAt;
        if (t != null && (latest == null || t.isAfter(latest))) {
          latest = t;
        }
      }
      if (latest != null) return latest;
    }
    return thread.receivedAt;
  }

  bool _evalBefore(String value, EmailThread thread, List<EmailMessage> messages) {
    final cutoff = parseQueryDate(value);
    if (cutoff == null) return false;
    final date = _threadDate(thread, messages);
    if (date == null) return false;
    return date.isBefore(cutoff);
  }

  bool _evalAfter(String value, EmailThread thread, List<EmailMessage> messages) {
    final cutoff = parseQueryDate(value);
    if (cutoff == null) return false;
    final date = _threadDate(thread, messages);
    if (date == null) return false;
    return date.isAfter(cutoff);
  }

  bool _evalDate(String value, EmailThread thread, List<EmailMessage> messages) {
    final target = parseQueryDate(value);
    if (target == null) return false;
    final date = _threadDate(thread, messages);
    if (date == null) return false;
    return date.year == target.year &&
        date.month == target.month &&
        date.day == target.day;
  }

  bool _evalAccount(String value) {
    final q = value.toLowerCase();
    return accountEmails.any((e) => e.toLowerCase().contains(q));
  }

  bool _evalIn(String value, EmailThread thread, List<EmailMessage> messages) {
    final q = value.toLowerCase();
    // Check current folder
    if (currentFolderPath != null &&
        currentFolderPath!.toLowerCase().contains(q)) {
      return true;
    }
    // Check message folder paths
    for (final m in messages) {
      if (m.folderPath != null && m.folderPath!.toLowerCase().contains(q)) {
        return true;
      }
    }
    return false;
  }

  bool _evalHas(String value, List<EmailMessage> messages) {
    return switch (value) {
      'attachment' || 'attachments' =>
          // We don't have attachment metadata in the model yet — stub as false.
          // TODO: add EmailMessage.hasAttachment
          false,
      'link' || 'links' => messages.any(
          (m) => (m.bodyPlainText).toLowerCase().contains('http') ||
              (m.bodyHtml ?? '').toLowerCase().contains('<a '),
        ),
      _ => false,
    };
  }

  bool _evalIs(String value, EmailThread thread, List<EmailMessage> messages) {
    return switch (value) {
      'unread' => thread.unread,
      'read' => !thread.unread,
      'starred' => thread.starred,
      'unstarred' => !thread.starred,
      'me' => messages.any((m) => m.isMe),
      'sent' => messages.any((m) => m.isMe),
      _ => false,
    };
  }
}
