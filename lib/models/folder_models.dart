import 'package:flutter/material.dart';

enum FolderSectionKind {
  mailboxes,
  folders,
  labels,
  savedSearches,
}

@immutable
class FolderSection {
  const FolderSection({
    required this.title,
    required this.items,
    required this.kind,
  });

  final String title;
  final List<FolderItem> items;
  final FolderSectionKind kind;
}

@immutable
class FolderItem {
  const FolderItem({
    required this.index,
    required this.name,
    required this.path,
    this.depth = 0,
    this.unreadCount = 0,
    this.icon,
  });

  final int index;
  final String name;
  final String path;
  final int depth;
  final int unreadCount;
  final IconData? icon;
}
