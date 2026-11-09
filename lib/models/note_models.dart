class NoteItem {
  const NoteItem({required this.id, required this.title, required this.categoryId,
    required this.folderId, required this.updatedAt, required this.archivedAt});
  final String id;
  final String? title;
  final String? categoryId;
  final String? folderId;
  final DateTime updatedAt;
  final DateTime? archivedAt;

  factory NoteItem.fromMap(Map<String, Object?> m) => NoteItem(
    id: m['id']! as String, title: m['title'] as String?,
    categoryId: m['category_id'] as String?, folderId: m['folder_id'] as String?,
    updatedAt: DateTime.fromMillisecondsSinceEpoch(m['updated_at']! as int),
    archivedAt: m['archived_at'] == null ? null :
      DateTime.fromMillisecondsSinceEpoch(m['archived_at']! as int));
}

class NotePageData {
  const NotePageData({required this.id, required this.noteId, required this.pageIndex,
    required this.strokesJson, required this.textsJson, required this.backgroundPath,
    required this.backgroundType, required this.pageColor});
  final String id;
  final String noteId;
  final int pageIndex;
  final String strokesJson;
  final String textsJson;
  final String? backgroundPath;
  final String? backgroundType;
  final int pageColor;

  factory NotePageData.fromMap(Map<String, Object?> m) => NotePageData(
    id: m['id']! as String, noteId: m['note_id']! as String,
    pageIndex: m['page_index']! as int, strokesJson: m['strokes_json']! as String,
    textsJson: m['texts_json']! as String, backgroundPath: m['background_path'] as String?,
    backgroundType: m['background_type'] as String?,
    pageColor: (m['page_color'] as int?) ?? 0xFFFFFFFF);
}
