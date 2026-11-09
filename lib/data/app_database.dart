import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final dir = await getApplicationDocumentsDirectory();
    _db = await openDatabase(
      p.join(dir.path, 'not_defteri.db'),
      version: 2,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        await db.execute('''CREATE TABLE categories(
          id TEXT PRIMARY KEY, name TEXT NOT NULL,
          updated_at INTEGER NOT NULL, archived_at INTEGER, delete_batch TEXT)''');
        await db.execute('''CREATE TABLE folders(
          id TEXT PRIMARY KEY, category_id TEXT NOT NULL, name TEXT NOT NULL,
          updated_at INTEGER NOT NULL, archived_at INTEGER, delete_batch TEXT,
          FOREIGN KEY(category_id) REFERENCES categories(id))''');
        await db.execute('''CREATE TABLE notes(
          id TEXT PRIMARY KEY, title TEXT, category_id TEXT, folder_id TEXT,
          updated_at INTEGER NOT NULL, archived_at INTEGER, delete_batch TEXT,
          FOREIGN KEY(category_id) REFERENCES categories(id),
          FOREIGN KEY(folder_id) REFERENCES folders(id))''');
        await db.execute('''CREATE TABLE pages(
          id TEXT PRIMARY KEY, note_id TEXT NOT NULL, page_index INTEGER NOT NULL,
          strokes_json TEXT NOT NULL DEFAULT '[]',
          texts_json TEXT NOT NULL DEFAULT '[]',
          background_path TEXT, background_type TEXT,
          page_color INTEGER NOT NULL DEFAULT 4294967295,
          FOREIGN KEY(note_id) REFERENCES notes(id) ON DELETE CASCADE)''');
        await db.execute('CREATE INDEX idx_notes_updated ON notes(updated_at)');
        await db.execute('CREATE INDEX idx_pages_note ON pages(note_id, page_index)');
        await db.execute('CREATE INDEX idx_folders_category ON folders(category_id)');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE pages ADD COLUMN background_type TEXT');
          await db.execute('ALTER TABLE pages ADD COLUMN page_color INTEGER NOT NULL DEFAULT 4294967295');
        }
      },
    );
    return _db!;
  }
}
