import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/notes_repository.dart';
import '../models/note_models.dart';
import 'note_editor_screen.dart';
import 'archive_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}
class _HomeScreenState extends State<HomeScreen> {
  late Future<NotesRepository> _repo;
  List<NoteItem> _notes = [];
  List<Map<String, Object?>> _categories = [];
  List<Map<String, Object?>> _folders = [];
  bool _byDate = false;
  String? _selectedCategory;
  String? _selectedFolder;

  @override
  void initState() { super.initState(); _repo = NotesRepository.create(); _load(); }

  Future<void> _load() async {
    final r = await _repo;
    final categories = await r.categories();
    final notes = await r.activeNotes(
      categoryId: _selectedFolder == null ? _selectedCategory : null,
      folderId: _selectedFolder);
    final folders = _selectedCategory == null ? <Map<String,Object?>>[] :
      await r.folders(_selectedCategory!);
    if (!mounted) return;
    setState(() { _categories = categories; _notes = notes; _folders = folders; });
  }

  Future<void> _newNote() async {
    final r = await _repo;
    final id = await r.createNote(categoryId: _selectedCategory,
      folderId: _selectedFolder);
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => NoteEditorScreen(noteId: id, repository: r)));
    _load();
  }

  Future<void> _createCategory() async {
    final name = await _askName('Yeni kategori');
    if (name == null || name.trim().isEmpty) return;
    final r = await _repo;
    await r.createCategory(name);
    _load();
  }

  Future<void> _createFolder(String categoryId) async {
    final name = await _askName('Yeni klasör');
    if (name == null || name.trim().isEmpty) return;
    final r = await _repo;
    await r.createFolder(categoryId, name);
    _load();
  }

  Future<String?> _askName(String title, {String initial = ''}) async {
    final c = TextEditingController(text: initial);
    return showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      title: Text(title), content: TextField(controller: c, autofocus: true,
        decoration: const InputDecoration(hintText: 'İsim')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
        FilledButton(onPressed: () => Navigator.pop(ctx, c.text),
          child: const Text('Kaydet')),
      ]));
  }

  Future<void> _noteMenu(NoteItem note) async {
    final action = await showModalBottomSheet<String>(context: context,
      builder: (ctx) => SafeArea(child: Wrap(children: [
        ListTile(leading: const Icon(Icons.edit), title: const Text('Aç / Düzenle'),
          onTap: () => Navigator.pop(ctx, 'edit')),
        ListTile(leading: const Icon(Icons.drive_file_rename_outline),
          title: const Text('Yeniden adlandır'),
          onTap: () => Navigator.pop(ctx, 'rename')),
        ListTile(leading: const Icon(Icons.archive_outlined), title: const Text('Arşive taşı'),
          onTap: () => Navigator.pop(ctx, 'archive')),
      ])));
    if (!mounted || action == null) return;
    final r = await _repo;
    if (action == 'edit') {
      await Navigator.push(context, MaterialPageRoute(
        builder: (_) => NoteEditorScreen(noteId: note.id, repository: r)));
    } else if (action == 'archive') {
      await r.archiveNote(note.id);
    } else if (action == 'rename') {
      final value = await _askName('Not başlığı', initial: note.title ?? '');
      if (value != null) await r.renameNote(note.id, value);
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final items = [..._notes];
    if (_byDate) items.sort((a,b) => b.updatedAt.compareTo(a.updatedAt));
    return Scaffold(
      appBar: AppBar(title: const Text('Not Defterim',
        style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(tooltip: 'Kategori ekle', onPressed: _createCategory,
            icon: const Icon(Icons.create_new_folder_outlined)),
          PopupMenuButton<bool>(initialValue: _byDate,
            onSelected: (v) => setState(() => _byDate = v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: false, child: Text('Varsayılan sıralama')),
              PopupMenuItem(value: true, child: Text('Son değişiklik tarihi')),
            ]),
        ]),
      body: RefreshIndicator(onRefresh: _load, child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 104),
        children: [
          if (_selectedCategory != null || _selectedFolder != null)
            ListTile(leading: const Icon(Icons.arrow_back),
              title: Text(_selectedFolder != null ? 'Klasörden çık' : 'Tüm notlar'),
              onTap: () { setState(() {
                if (_selectedFolder != null) { _selectedFolder = null; }
                else { _selectedCategory = null; }
              }); _load(); }),
          if (_selectedCategory == null) ...[
            const Padding(padding: EdgeInsets.fromLTRB(8, 12, 8, 4),
              child: Text('KATEGORİLER', style: TextStyle(fontWeight: FontWeight.bold,
                color: Colors.blueGrey, letterSpacing: 1))),
            ..._categories.map((c) => Card(
              elevation: 0, child: ListTile(
                leading: const Icon(Icons.folder_special_outlined),
                title: Text(c['name']! as String,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('Son değişiklik: ${_date(c['updated_at'] as int)}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () { setState(() => _selectedCategory = c['id']! as String); _load(); },
                onLongPress: () async {
                  final ok = await showDialog<bool>(context: context, builder: (ctx) =>
                    AlertDialog(title: const Text('Kategoriyi arşivle?'),
                      content: const Text('Aktif klasör ve notları da arşive taşınır.'),
                      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Vazgeç')), FilledButton(onPressed: () =>
                        Navigator.pop(ctx, true), child: const Text('Arşivle'))]));
                  if (ok == true) { final r = await _repo;
                    await r.archiveCategory(c['id']! as String); _load(); }
                },
              )))
          ] else ...[
            Row(children: [
              Expanded(child: Padding(padding: const EdgeInsets.all(8),
                child: Text(_categories.firstWhere((c) => c['id'] == _selectedCategory,
                  orElse: () => {'name':'Kategori'})['name']! as String,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)))),
              TextButton.icon(onPressed: () => _createFolder(_selectedCategory!),
                icon: const Icon(Icons.create_new_folder), label: const Text('Klasör')),
            ]),
            ..._folders.map((f) => Card(elevation: 0, child: ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: Text(f['name']! as String,
                style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Son değişiklik: ${_date(f['updated_at'] as int)}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () { setState(() => _selectedFolder = f['id']! as String); _load(); },
              onLongPress: () async {
                final ok = await showDialog<bool>(context: context, builder: (ctx) =>
                  AlertDialog(title: const Text('Klasörü arşivle?'),
                    content: const Text('Klasördeki aktif notlar da arşive taşınır.'),
                    actions: [TextButton(onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Vazgeç')), FilledButton(onPressed: () =>
                      Navigator.pop(ctx, true), child: const Text('Arşivle'))]));
                if (ok == true) { final r = await _repo;
                  await r.archiveFolder(f['id']! as String); _load(); }
              },
            )))
          ],
          const Padding(padding: EdgeInsets.fromLTRB(8, 16, 8, 4),
            child: Text('NOTLAR', style: TextStyle(fontWeight: FontWeight.bold,
              color: Colors.blueGrey, letterSpacing: 1))),
          if (items.isEmpty) const Padding(padding: EdgeInsets.all(24),
            child: Center(child: Text('Henüz not yok. Ekle düğmesiyle başlayın.'))),
          ...items.map((n) => Card(elevation: 0, child: GestureDetector(
            onLongPress: () => _noteMenu(n),
            child: ListTile(leading: const Icon(Icons.description_outlined),
              title: Text(n.title ?? 'Başlık Yok',
                style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('Son değişiklik: ${DateFormat('dd.MM.yyyy HH:mm').format(n.updatedAt)}'),
              onTap: () async {
                final r = await _repo;
                if (!mounted) return;
                await Navigator.push(context, MaterialPageRoute(
                  builder: (_) => NoteEditorScreen(noteId: n.id, repository: r)));
                _load();
              }),
          ))),
        ],
      )),
      floatingActionButton: FloatingActionButton.extended(onPressed: _newNote,
        icon: const Icon(Icons.add), label: const Text('Ekle')),
      bottomNavigationBar: SafeArea(child: Padding(padding: const EdgeInsets.all(10),
        child: Row(children: [
          OutlinedButton.icon(onPressed: () async {
            final r = await _repo;
            if (!mounted) return;
            await Navigator.push(context, MaterialPageRoute(
              builder: (_) => ArchiveScreen(repository: r)));
            _load();
          }, icon: const Icon(Icons.archive_outlined), label: const Text('Arşiv')),
          const Spacer(),
          const Text('Yerel kayıt açık', style: TextStyle(color: Colors.green)),
        ]))),
    );
  }

  String _date(int ms) => DateFormat('dd.MM.yyyy').format(
    DateTime.fromMillisecondsSinceEpoch(ms));
}
