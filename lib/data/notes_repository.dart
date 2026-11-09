import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../models/note_models.dart';
import 'app_database.dart';

class NotesRepository {
  NotesRepository(this.db);
  final Database db;
  static const _uuid = Uuid();
  static Future<NotesRepository> create() async =>
      NotesRepository(await AppDatabase.instance.database);

  String? _clean(String? value) {
    final v = value?.trim();
    return (v == null || v.isEmpty) ? null : v;
  }

  Future<void> _touchParents(Transaction txn, String? categoryId,
      String? folderId, int now) async {
    if (folderId != null) {
      await txn.update('folders', {'updated_at': now},
          where: 'id=? AND archived_at IS NULL', whereArgs: [folderId]);
    }
    if (categoryId != null) {
      await txn.update('categories', {'updated_at': now},
          where: 'id=? AND archived_at IS NULL', whereArgs: [categoryId]);
    }
  }

  Future<String> createNote({String? title, String? categoryId, String? folderId}) async {
    final id = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      await txn.insert('notes', {'id': id, 'title': _clean(title),
        'category_id': categoryId, 'folder_id': folderId, 'updated_at': now});
      await txn.insert('pages', {'id': _uuid.v4(), 'note_id': id, 'page_index': 0,
        'strokes_json': '[]', 'texts_json': '[]'});
      await _touchParents(txn, categoryId, folderId, now);
    });
    return id;
  }

  Future<void> createCategory(String name) async {
    final value = _clean(name);
    if (value == null) throw ArgumentError('Kategori adı boş olamaz.');
    await db.insert('categories', {'id': _uuid.v4(), 'name': value,
      'updated_at': DateTime.now().millisecondsSinceEpoch});
  }

  Future<void> createFolder(String categoryId, String name) async {
    final value = _clean(name);
    if (value == null) throw ArgumentError('Klasör adı boş olamaz.');
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      await txn.insert('folders', {'id': _uuid.v4(), 'category_id': categoryId,
        'name': value, 'updated_at': now});
      await txn.update('categories', {'updated_at': now},
          where: 'id=?', whereArgs: [categoryId]);
    });
  }

  Future<List<Map<String, Object?>>> categories({bool archived = false}) =>
      db.query('categories', where: archived ? 'archived_at IS NOT NULL' : 'archived_at IS NULL',
          orderBy: 'updated_at DESC');

  Future<List<Map<String, Object?>>> folders(String categoryId, {bool archived = false}) =>
      db.query('folders', where: 'category_id=? AND ${archived ? 'archived_at IS NOT NULL' : 'archived_at IS NULL'}',
          whereArgs: [categoryId], orderBy: 'updated_at DESC');

  Future<List<Map<String, Object?>>> archivedFolders() =>
      db.query('folders', where: 'archived_at IS NOT NULL', orderBy: 'archived_at DESC');

  Future<List<Map<String, Object?>>> archivedCategories() =>
      db.query('categories', where: 'archived_at IS NOT NULL', orderBy: 'archived_at DESC');

  Future<List<NoteItem>> activeNotes({String? categoryId, String? folderId}) async {
    final clauses = <String>['archived_at IS NULL'];
    final args = <Object?>[];
    if (categoryId != null) { clauses.add('category_id=?'); args.add(categoryId); }
    if (folderId != null) { clauses.add('folder_id=?'); args.add(folderId); }
    final rows = await db.query('notes', where: clauses.join(' AND '),
        whereArgs: args, orderBy: 'updated_at DESC');
    return rows.map(NoteItem.fromMap).toList();
  }

  Future<List<NoteItem>> archivedNotes() async {
    final rows = await db.query('notes', where: 'archived_at IS NOT NULL',
        orderBy: 'archived_at DESC');
    return rows.map(NoteItem.fromMap).toList();
  }

  Future<List<NotePageData>> pages(String noteId) async {
    final rows = await db.query('pages', where: 'note_id=?',
        whereArgs: [noteId], orderBy: 'page_index');
    return rows.map(NotePageData.fromMap).toList();
  }

  Future<String?> noteTitle(String noteId) async {
    final rows = await db.query('notes', columns: ['title'],
        where: 'id=?', whereArgs: [noteId], limit: 1);
    return rows.isEmpty ? null : rows.first['title'] as String?;
  }

  Future<void> savePage(NotePageData page, {String? title}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      await txn.update('pages', {
        'strokes_json': page.strokesJson, 'texts_json': page.textsJson,
        'background_path': page.backgroundPath, 'background_type': page.backgroundType,
        'page_color': page.pageColor,
      }, where: 'id=?', whereArgs: [page.id]);
      await txn.update('notes', {'title': _clean(title), 'updated_at': now},
          where: 'id=?', whereArgs: [page.noteId]);
      final note = await txn.query('notes', columns: ['category_id','folder_id'],
          where: 'id=?', whereArgs: [page.noteId], limit: 1);
      if (note.isNotEmpty) {
        await _touchParents(txn, note.first['category_id'] as String?,
            note.first['folder_id'] as String?, now);
      }
    });
  }

  Future<String> addPage(String noteId) async {
    final id = _uuid.v4();
    await db.transaction((txn) async {
      final count = Sqflite.firstIntValue(await txn.rawQuery(
          'SELECT COUNT(*) FROM pages WHERE note_id=?', [noteId])) ?? 0;
      await txn.insert('pages', {'id': id, 'note_id': noteId, 'page_index': count,
        'strokes_json': '[]', 'texts_json': '[]'});
      await txn.update('notes', {'updated_at': DateTime.now().millisecondsSinceEpoch},
          where: 'id=?', whereArgs: [noteId]);
    });
    return id;
  }

  Future<void> renameNote(String id, String? title) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      final rows = await txn.query('notes', columns: ['category_id','folder_id'],
          where: 'id=?', whereArgs: [id], limit: 1);
      await txn.update('notes', {'title': _clean(title), 'updated_at': now},
          where: 'id=?', whereArgs: [id]);
      if (rows.isNotEmpty) {
        await _touchParents(txn, rows.first['category_id'] as String?,
            rows.first['folder_id'] as String?, now);
      }
    });
  }

  // Only currently-active descendants receive this batch. Previously archived
  // children keep their own batch and therefore are not accidentally restored.
  Future<void> archiveNote(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final batch = _uuid.v4();
    await db.transaction((txn) async {
      final rows = await txn.query('notes', columns: ['category_id','folder_id'],
          where: 'id=? AND archived_at IS NULL', whereArgs: [id]);
      if (rows.isEmpty) return;
      await txn.update('notes', {'archived_at': now, 'delete_batch': batch},
          where: 'id=? AND archived_at IS NULL', whereArgs: [id]);
      await _touchParents(txn, rows.first['category_id'] as String?,
          rows.first['folder_id'] as String?, now);
    });
  }

  Future<void> archiveFolder(String folderId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final batch = _uuid.v4();
    await db.transaction((txn) async {
      final folder = await txn.query('folders', columns: ['category_id'],
          where: 'id=? AND archived_at IS NULL', whereArgs: [folderId]);
      if (folder.isEmpty) return;
      await txn.update('folders', {'archived_at': now, 'delete_batch': batch},
          where: 'id=? AND archived_at IS NULL', whereArgs: [folderId]);
      await txn.update('notes', {'archived_at': now, 'delete_batch': batch},
          where: 'folder_id=? AND archived_at IS NULL', whereArgs: [folderId]);
      await txn.update('categories', {'updated_at': now},
          where: 'id=?', whereArgs: [folder.first['category_id']]);
    });
  }

  Future<void> archiveCategory(String categoryId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final batch = _uuid.v4();
    await db.transaction((txn) async {
      final exists = await txn.query('categories', columns: ['id'],
          where: 'id=? AND archived_at IS NULL', whereArgs: [categoryId]);
      if (exists.isEmpty) return;
      await txn.update('categories', {'archived_at': now, 'delete_batch': batch},
          where: 'id=? AND archived_at IS NULL', whereArgs: [categoryId]);
      final folderRows = await txn.query('folders', columns: ['id'],
          where: 'category_id=? AND archived_at IS NULL', whereArgs: [categoryId]);
      final folderIds = folderRows.map((r) => r['id'] as String).toList();
      await txn.update('folders', {'archived_at': now, 'delete_batch': batch},
          where: 'category_id=? AND archived_at IS NULL', whereArgs: [categoryId]);
      if (folderIds.isEmpty) {
        await txn.update('notes', {'archived_at': now, 'delete_batch': batch},
            where: 'category_id=? AND archived_at IS NULL', whereArgs: [categoryId]);
      } else {
        final marks = List.filled(folderIds.length, '?').join(',');
        await txn.rawUpdate('UPDATE notes SET archived_at=?, delete_batch=? WHERE archived_at IS NULL AND (category_id=? OR folder_id IN ($marks))',
            [now, batch, categoryId, ...folderIds]);
      }
    });
  }

  Future<void> restoreNote(String id) async =>
      db.update('notes', {'archived_at': null, 'delete_batch': null},
          where: 'id=?', whereArgs: [id]);

  Future<void> restoreFolder(String id) async {
    await db.transaction((txn) async {
      final rows = await txn.query('folders', columns: ['delete_batch','category_id'],
          where: 'id=?', whereArgs: [id]);
      if (rows.isEmpty) return;
      final batch = rows.first['delete_batch'];
      await txn.update('folders', {'archived_at': null, 'delete_batch': null},
          where: 'id=?', whereArgs: [id]);
      if (batch != null) {
        await txn.update('notes', {'archived_at': null, 'delete_batch': null},
            where: 'delete_batch=? AND folder_id=?', whereArgs: [batch, id]);
      }
    });
  }

  Future<void> restoreCategory(String id) async {
    await db.transaction((txn) async {
      final rows = await txn.query('categories', columns: ['delete_batch'],
          where: 'id=?', whereArgs: [id]);
      if (rows.isEmpty) return;
      final batch = rows.first['delete_batch'];
      if (batch == null) return;
      await txn.update('categories', {'archived_at': null, 'delete_batch': null},
          where: 'id=?', whereArgs: [id]);
      await txn.update('folders', {'archived_at': null, 'delete_batch': null},
          where: 'delete_batch=? AND category_id=?', whereArgs: [batch, id]);
      await txn.update('notes', {'archived_at': null, 'delete_batch': null},
          where: 'delete_batch=? AND (category_id=? OR folder_id IN (SELECT id FROM folders WHERE category_id=?))',
          whereArgs: [batch, id, id]);
    });
  }

  Future<void> permanentlyDeleteNote(String id) async {
    await db.transaction((txn) async {
      await txn.delete('pages', where: 'note_id=?', whereArgs: [id]);
      await txn.delete('notes', where: 'id=?', whereArgs: [id]);
    });
  }

  Future<void> permanentlyDeleteFolder(String id) async {
    await db.transaction((txn) async {
      final notes = await txn.query('notes', columns: ['id'], where: 'folder_id=?', whereArgs: [id]);
      for (final n in notes) {
        await txn.delete('pages', where: 'note_id=?', whereArgs: [n['id']]);
      }
      await txn.delete('notes', where: 'folder_id=?', whereArgs: [id]);
      await txn.delete('folders', where: 'id=?', whereArgs: [id]);
    });
  }

  Future<void> permanentlyDeleteCategory(String id) async {
    await db.transaction((txn) async {
      final folders = await txn.query('folders', columns: ['id'],
          where: 'category_id=?', whereArgs: [id]);
      final folderIds = folders.map((r) => r['id'] as String).toList();
      final List<Map<String, Object?>> notes;
      if (folderIds.isEmpty) {
        notes = await txn.query('notes', columns: ['id'],
            where: 'category_id=?', whereArgs: [id]);
      } else {
        final marks = List.filled(folderIds.length, '?').join(',');
        notes = await txn.rawQuery(
          'SELECT id FROM notes WHERE category_id=? OR folder_id IN ($marks)',
          [id, ...folderIds]);
      }
      for (final n in notes) {
        await txn.delete('pages', where: 'note_id=?', whereArgs: [n['id']]);
      }
      if (folderIds.isEmpty) {
        await txn.delete('notes', where: 'category_id=?', whereArgs: [id]);
      } else {
        final marks = List.filled(folderIds.length, '?').join(',');
        await txn.rawDelete(
          'DELETE FROM notes WHERE category_id=? OR folder_id IN ($marks)',
          [id, ...folderIds]);
      }
      await txn.delete('folders', where: 'category_id=?', whereArgs: [id]);
      await txn.delete('categories', where: 'id=?', whereArgs: [id]);
    });
  }

  Future<String> exportNoteJson(String noteId) async {
    final note = await db.query('notes', where: 'id=?', whereArgs: [noteId], limit: 1);
    final pageRows = await db.query('pages', where: 'note_id=?',
        whereArgs: [noteId], orderBy: 'page_index');
    return jsonEncode({'note': note.first, 'pages': pageRows});
  }
}
