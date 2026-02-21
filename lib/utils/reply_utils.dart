import '../models/email_models.dart';

/// Returns the effective reply-to [EmailAddress] for a single-recipient reply,
/// honouring the Reply-To header (RFC 5322 §3.6.2) before falling back to From.
///
/// Prefers the first entry in [replyToAddresses] when non-empty; otherwise uses
/// [from]. If the resolved sender is the current user, picks the first other
/// participant from [participants] instead.  Returns `null` only when no
/// reasonable address can be found.
EmailAddress? effectiveReplyTo({
  required List<EmailAddress> replyToAddresses,
  required EmailAddress? from,
  required List<EmailAddress> participants,
  required String currentUserEmail,
}) {
  final preferred = replyToAddresses.isNotEmpty ? replyToAddresses.first : from;
  if (preferred != null && preferred.email != currentUserEmail) {
    return preferred;
  }
  // Sender is "me" — find the first other participant.
  return participants.cast<EmailAddress?>().firstWhere(
    (p) => p!.email != currentUserEmail,
    orElse: () => preferred,
  );
}
