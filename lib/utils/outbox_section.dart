import 'package:flutter/material.dart';

import '../models/folder_models.dart';
import '../state/send_queue.dart';

/// Inserts an Outbox entry into the Mailboxes section of [sections].
///
/// If [sections] is empty, returns a single-section list containing only the
/// Outbox.  If the Mailboxes section already has an Outbox item (idempotent
/// after hot reload), it is left unchanged.
List<FolderSection> withOutboxSection(
  List<FolderSection> sections,
  SendQueue sendQueue,
) {
  final outboxItem = FolderItem(
    index: -1,
    name: 'Outbox',
    path: kOutboxFolderPath,
    unreadCount: sendQueue.pendingCount,
    icon: Icons.outbox_rounded,
  );

  if (sections.isEmpty) {
    return [
      FolderSection(
        title: 'Mailboxes',
        kind: FolderSectionKind.mailboxes,
        items: [outboxItem],
      ),
    ];
  }

  return sections.map((section) {
    if (section.kind != FolderSectionKind.mailboxes) return section;
    final hasOutbox =
        section.items.any((item) => item.path == kOutboxFolderPath);
    if (hasOutbox) return section;
    return FolderSection(
      title: section.title,
      kind: section.kind,
      items: [outboxItem, ...section.items],
    );
  }).toList();
}
