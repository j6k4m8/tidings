import '../utils/subject_utils.dart';

/// Groups IMAP messages into conversation threads by their **Message-ID /
/// In-Reply-To lineage** (RFC 5322), not by subject. Two unrelated messages
/// that merely share a subject (e.g. two different "Fwd: …") therefore never
/// collapse into one thread. Subject is consulted only as a last resort for
/// messages that carry no Message-ID at all.
///
/// State accumulates across folder reloads (it is never cleared) so a given
/// conversation keeps a stable thread id, and out-of-order arrivals still link
/// up: each message pre-registers its parent's Message-ID against its thread,
/// so an ancestor fetched later joins the thread its descendants created.
class ThreadResolver {
  final Map<String, String> _messageIdToThreadId = {};
  final Map<String, String> _subjectThreadId = {};

  /// Returns the thread id for a message with the given [subject], [messageId]
  /// (its `Message-ID`) and [inReplyTo] (its `In-Reply-To`).
  String resolve({
    required String subject,
    String? messageId,
    String? inReplyTo,
  }) {
    final hasMessageId = messageId != null && messageId.isNotEmpty;
    final hasInReplyTo = inReplyTo != null && inReplyTo.isNotEmpty;

    // 1. Lineage: a reply to a message we've already placed joins its thread.
    if (hasInReplyTo) {
      final existing = _messageIdToThreadId[inReplyTo];
      if (existing != null) {
        if (hasMessageId) {
          _messageIdToThreadId[messageId] = existing;
        }
        return existing;
      }
    }

    // 2. This message may already be mapped — e.g. an out-of-order reply that
    //    arrived earlier pre-registered our Message-ID as its parent.
    if (hasMessageId) {
      final existing = _messageIdToThreadId[messageId];
      if (existing != null) {
        // Keep linking upward so an out-of-order ancestor joins too.
        if (hasInReplyTo) {
          _messageIdToThreadId.putIfAbsent(inReplyTo, () => existing);
        }
        return existing;
      }
    }

    // 3. No lineage match → start a NEW thread. Key it by this message's own
    //    Message-ID so distinct conversations never collapse on subject alone.
    final String threadId;
    if (hasMessageId) {
      threadId = 'imap-mid-${messageId.hashCode}';
      _messageIdToThreadId[messageId] = threadId;
    } else {
      // Last resort: no Message-ID at all — fall back to subject grouping.
      final normalized = normalizeSubject(subject);
      threadId = _subjectThreadId.putIfAbsent(
        normalized,
        () => 'imap-sub-${normalized.hashCode}',
      );
    }

    // Pre-register the parent so an out-of-order ancestor joins this thread.
    if (hasInReplyTo) {
      _messageIdToThreadId.putIfAbsent(inReplyTo, () => threadId);
    }
    return threadId;
  }
}
