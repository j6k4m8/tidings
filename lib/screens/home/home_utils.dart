import '../../models/folder_models.dart';

int selectedIndex(int index, int length) {
  if (length <= 0) {
    return 0;
  }
  return index.clamp(0, length - 1);
}

List<FolderItem> mailboxItems(List<FolderSection> sections) {
  for (final section in sections) {
    if (section.kind == FolderSectionKind.mailboxes) {
      return section.items;
    }
  }
  return const [];
}

List<FolderItem> pinnedItems(
  List<FolderSection> sections,
  Set<String> pinnedPaths,
) {
  if (pinnedPaths.isEmpty) {
    return const [];
  }
  final items = <FolderItem>[];
  for (final section in sections) {
    for (final item in section.items) {
      if (pinnedPaths.contains(item.path)) {
        items.add(item);
      }
    }
  }
  return items;
}

String? folderLabelForPath(
  List<FolderSection> sections,
  String path,
) {
  for (final section in sections) {
    for (final item in section.items) {
      if (item.path == path) {
        return item.name;
      }
    }
  }
  return null;
}
