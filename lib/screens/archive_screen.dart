import 'package:flutter/material.dart';
import '../data/notes_repository.dart';
import '../models/note_models.dart';

class ArchiveScreen extends StatefulWidget {
  const ArchiveScreen({super.key, required this.repository});
  final NotesRepository repository;
  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> {
  List<NoteItem> _notes = [];
  List<Map<String, Object?>> _categories = [];
  List<Map<String, Object?>> _folders = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _refresh(); }

  Future<void> _refresh() async {
    final notes = await widget.repository.archivedNotes();
    final categories = await widget.repository.archivedCategories();
    final folders = await widget.repository.archivedFolders();
    if (!mounted) return;
    setState(() { _notes = notes; _categories = categories;
      _folders = folders; _loading = false; });
  }

  Future<bool> _confirm(String title) async => await showDialog<bool>(
    context: context, builder: (ctx) => AlertDialog(
      title: Text(title), content: const Text('Bu işlem geri alınamaz.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Vazgeç')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Kalıcı sil')),
      ])) ?? false;

  Future<void> _restoreNote(NoteItem n) async {
    await widget.repository.restoreNote(n.id);
    await _refresh();
  }
  Future<void> _deleteNote(NoteItem n) async {
    if (!await _confirm('Not kalıcı olarak silinsin mi?')) return;
    await widget.repository.permanentlyDeleteNote(n.id);
    await _refresh();
  }
  Future<void> _restoreFolder(Map<String,Object?> f) async {
    await widget.repository.restoreFolder(f['id']! as String);
    await _refresh();
  }
  Future<void> _deleteFolder(Map<String,Object?> f) async {
    if (!await _confirm('Klasör ve içeriği kalıcı silinsin mi?')) return;
    await widget.repository.permanentlyDeleteFolder(f['id']! as String);
    await _refresh();
  }
  Future<void> _restoreCategory(Map<String,Object?> c) async {
    await widget.repository.restoreCategory(c['id']! as String);
    await _refresh();
  }
  Future<void> _deleteCategory(Map<String,Object?> c) async {
    if (!await _confirm('Kategori ve içeriği kalıcı silinsin mi?')) return;
    await widget.repository.permanentlyDeleteCategory(c['id']! as String);
    await _refresh();
  }

  Widget _actions(VoidCallback restore, VoidCallback delete) => Wrap(children: [
    IconButton(tooltip: 'Geri yükle', onPressed: restore,
      icon: const Icon(Icons.restore)),
    IconButton(tooltip: 'Kalıcı sil', onPressed: delete,
      icon: const Icon(Icons.delete_forever_outlined)),
  ]);

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Arşiv')),
    body: _loading ? const Center(child: CircularProgressIndicator()) :
      RefreshIndicator(onRefresh: _refresh, child: ListView(
        children: [
          if (_categories.isNotEmpty) const ListTile(title: Text('KATEGORİLER',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey))),
          ..._categories.map((c) => ListTile(
            leading: const Icon(Icons.folder_special_outlined),
            title: Text(c['name']! as String),
            subtitle: const Text('Kategori ve silinirken aktif olan alt öğeleri'),
            trailing: _actions(() => _restoreCategory(c), () => _deleteCategory(c)))),
          if (_folders.isNotEmpty) const ListTile(title: Text('KLASÖRLER',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey))),
          ..._folders.map((f) => ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: Text(f['name']! as String),
            trailing: _actions(() => _restoreFolder(f), () => _deleteFolder(f)))),
          if (_notes.isNotEmpty) const ListTile(title: Text('NOTLAR',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey))),
          ..._notes.map((n) => ListTile(
            leading: const Icon(Icons.description_outlined),
            title: Text(n.title ?? 'Başlık Yok'),
            trailing: _actions(() => _restoreNote(n), () => _deleteNote(n)))),
          if (_categories.isEmpty && _folders.isEmpty && _notes.isEmpty)
            const Padding(padding: EdgeInsets.all(32),
              child: Center(child: Text('Arşiv boş.'))),
        ],
      )),
  );
}
