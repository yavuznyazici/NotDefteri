import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../data/notes_repository.dart';
import '../models/note_models.dart';
import '../widgets/drawing_canvas.dart';

class NoteEditorScreen extends StatefulWidget {
  const NoteEditorScreen({super.key, required this.noteId, required this.repository});
  final String noteId;
  final NotesRepository repository;
  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen>
    with WidgetsBindingObserver {
  final _title = TextEditingController();
  final _picker = ImagePicker();
  List<NotePageData> _pages = [];
  List<InkStroke> _strokes = [];
  List<Map<String, dynamic>> _texts = [];
  final List<List<InkStroke>> _undo = [];
  final List<List<InkStroke>> _redo = [];
  InkStroke? _active;
  int _index = 0;
  Timer? _saveTimer;
  bool _dirty = false;
  bool _loading = true;
  DrawingTool _tool = DrawingTool.pen;
  Color _color = const Color(0xFF202124);
  double _width = 2.5;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  Future<void> _load() async {
    final rows = await widget.repository.pages(widget.noteId);
    final title = await widget.repository.noteTitle(widget.noteId);
    if (!mounted) return;
    _title.text = title ?? '';
    setState(() { _pages = rows; _loading = false; });
    if (_pages.isNotEmpty) _readStrokes();
  }

  void _readStrokes() {
    try {
      final decoded = jsonDecode(_pages[_index].strokesJson) as List;
      _strokes = decoded.map((s) =>
        InkStroke.fromJson(Map<String, dynamic>.from(s as Map))).toList();
    } catch (_) { _strokes = []; }
    try {
      _texts = (jsonDecode(_pages[_index].textsJson) as List)
        .map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) { _texts = []; }
    _undo.clear();
    _redo.clear();
  }

  void _checkpoint() {
    _undo.add(_strokes.map((s) => InkStroke(points: [...s.points],
      color: s.color, width: s.width, tool: s.tool)).toList());
    if (_undo.length > 60) _undo.removeAt(0);
    _redo.clear();
  }

  void _changed() {
    _dirty = true;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 1), _save);
  }

  Future<void> _save() async {
    if (!_dirty || _pages.isEmpty) return;
    _dirty = false;
    final encoded = jsonEncode(_strokes.map((s) => s.toJson()).toList());
    final old = _pages[_index];
    final updated = NotePageData(id: old.id, noteId: old.noteId,
      pageIndex: old.pageIndex, strokesJson: encoded,
      textsJson: jsonEncode(_texts), backgroundPath: old.backgroundPath, backgroundType: old.backgroundType,
      pageColor: old.pageColor);
    await widget.repository.savePage(updated, title: _title.text);
    _pages[_index] = updated;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _saveTimer?.cancel();
      _save();
    }
  }

  Future<void> _switchPage(int next) async {
    await _save();
    if (next < 0 || next >= _pages.length) return;
    setState(() { _index = next; _readStrokes(); });
  }

  Future<void> _addPage() async {
    await _save();
    await widget.repository.addPage(widget.noteId);
    final rows = await widget.repository.pages(widget.noteId);
    if (!mounted) return;
    setState(() { _pages = rows; _index = rows.length - 1; _readStrokes(); });
  }

  Future<void> _addImage() async {
    final image = await _picker.pickImage(source: ImageSource.gallery,
      imageQuality: 92, maxWidth: 2400);
    if (image == null || !mounted) return;
    final appDir = await getApplicationDocumentsDirectory();
    final mediaDir = Directory(p.join(appDir.path, 'media'));
    await mediaDir.create(recursive: true);
    final extension = p.extension(image.path).isEmpty ? '.jpg' : p.extension(image.path);
    final savedImage = await File(image.path).copy(
      p.join(mediaDir.path, '${DateTime.now().microsecondsSinceEpoch}$extension'));
    final old = _pages[_index];
    final updated = NotePageData(id: old.id, noteId: old.noteId,
      pageIndex: old.pageIndex, strokesJson: old.strokesJson,
      textsJson: old.textsJson, backgroundPath: savedImage.path,
      backgroundType: 'image', pageColor: old.pageColor);
    await widget.repository.savePage(updated, title: _title.text);
    setState(() => _pages[_index] = updated);
  }

  Future<void> _addText() async {
    final controller = TextEditingController();
    final value = await showDialog<String>(context: context, builder: (ctx) =>
      AlertDialog(title: const Text('Sayfaya metin ekle'),
        content: TextField(controller: controller, autofocus: true,
          minLines: 1, maxLines: 5, decoration: const InputDecoration(
            hintText: 'Metninizi yazın')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
            child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Ekle')),
        ]));
    if (value == null || value.trim().isEmpty || !mounted) return;
    setState(() => _texts.add({'text': value.trim(), 'x': 32.0, 'y': 48.0,
      'size': 20.0, 'color': Colors.black.toARGB32()}));
    _changed();
  }

  void _undoStroke() {
    if (_undo.isEmpty) return;
    _redo.add(_strokes.map((s) => InkStroke(points: [...s.points],
      color: s.color, width: s.width, tool: s.tool)).toList());
    setState(() => _strokes = _undo.removeLast());
    _changed();
  }

  void _redoStroke() {
    if (_redo.isEmpty) return;
    _undo.add(_strokes.map((s) => InkStroke(points: [...s.points],
      color: s.color, width: s.width, tool: s.tool)).toList());
    setState(() => _strokes = _redo.removeLast());
    _changed();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveTimer?.cancel();
    if (_dirty) _save();
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final page = _pages.isEmpty ? null : _pages[_index];
    return Scaffold(
      appBar: AppBar(
        title: TextField(controller: _title, onChanged: (_) => _changed(),
          decoration: const InputDecoration(hintText: 'Başlık (isteğe bağlı)',
            border: InputBorder.none)),
        actions: [
          IconButton(onPressed: _save, icon: const Icon(Icons.save_outlined),
            tooltip: 'Kaydet'),
          PopupMenuButton<String>(onSelected: (v) {
            if (v == 'image') _addImage();
          }, itemBuilder: (_) => const [
            PopupMenuItem(value: 'image', child: Text('Arka plana resim ekle')),
          ]),
        ],
      ),
      body: Column(children: [
        Expanded(child: Padding(padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(color: page == null ? Colors.white :
              Color(page.pageColor), borderRadius: BorderRadius.circular(5),
              boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 8)]),
            clipBehavior: Clip.antiAlias,
            child: Stack(fit: StackFit.expand, children: [
              if (page?.backgroundPath != null &&
                  File(page!.backgroundPath!).existsSync())
                Image.file(File(page.backgroundPath!), fit: BoxFit.contain),
              ..._texts.asMap().entries.map((entry) {
                final i = entry.key; final item = entry.value;
                return Positioned(
                  left: (item['x'] as num).toDouble(),
                  top: (item['y'] as num).toDouble(),
                  child: GestureDetector(
                    onPanUpdate: (d) {
                      setState(() {
                        item['x'] = ((item['x'] as num).toDouble() + d.delta.dx).clamp(0, 2000);
                        item['y'] = ((item['y'] as num).toDouble() + d.delta.dy).clamp(0, 3000);
                      });
                      _changed();
                    },
                    onLongPress: () {
                      setState(() => _texts.removeAt(i));
                      _changed();
                    },
                    child: Text(item['text'] as String,
                      style: TextStyle(fontSize: (item['size'] as num).toDouble(),
                        color: Color((item['color'] as num).toInt()),
                        backgroundColor: Colors.white.withValues(alpha: 0.35))),
                  ),
                );
              }),
              DrawingCanvas(strokes: _strokes, tool: _tool, color: _color,
                width: _width,
                onStart: (point) {
                  _checkpoint();
                  setState(() {
                    _active = InkStroke(points: [point], color: _color,
                      width: _width, tool: _tool);
                    _strokes.add(_active!);
                  });
                },
                onMove: (point) {
                  setState(() => _active?.points.add(point));
                  _changed();
                },
                onEnd: () { _active = null; _changed(); }),
            ]),
          ))),
        _toolbar(),
        SafeArea(top: false, child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            IconButton(onPressed: _index > 0 ? () => _switchPage(_index - 1) : null,
              icon: const Icon(Icons.chevron_left)),
            Text('${_pages.isEmpty ? 0 : _index + 1} / ${_pages.length}'),
            IconButton(onPressed: _index < _pages.length - 1 ?
              () => _switchPage(_index + 1) : null, icon: const Icon(Icons.chevron_right)),
            IconButton(onPressed: _addPage, icon: const Icon(Icons.add_box_outlined),
              tooltip: 'Sayfa ekle'),
          ])),
      ]),
    );
  }

  Widget _toolbar() => Material(
    color: Theme.of(context).colorScheme.surface,
    child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4, children: [
          IconButton(tooltip: 'Kalem', isSelected: _tool == DrawingTool.pen,
            onPressed: () => setState(() => _tool = DrawingTool.pen),
            icon: const Icon(Icons.edit)),
          IconButton(tooltip: 'Fosforlu kalem', isSelected: _tool == DrawingTool.highlighter,
            onPressed: () => setState(() { _tool = DrawingTool.highlighter; _color = Colors.yellow; }),
            icon: const Icon(Icons.highlight)),
          IconButton(tooltip: 'Silgi', isSelected: _tool == DrawingTool.eraser,
            onPressed: () => setState(() => _tool = DrawingTool.eraser),
            icon: const Icon(Icons.auto_fix_normal)),
          PopupMenuButton<Color>(
            tooltip: 'Kalem rengi',
            onSelected: (c) => setState(() { _color = c; _tool = DrawingTool.pen; }),
            itemBuilder: (_) => [
              Colors.black, Colors.blue, Colors.red, Colors.green, Colors.purple,
              Colors.orange, Colors.yellow,
            ].map((c) => PopupMenuItem(value: c, child: Row(children: [
              Icon(Icons.circle, color: c, size: 18), const SizedBox(width: 8),
              Text(c.toString()),
            ]))).toList(),
            child: const Padding(padding: EdgeInsets.all(10),
              child: Icon(Icons.palette_outlined)),
          ),
          SizedBox(width: 100, child: Slider(value: _width.clamp(1, 12),
            min: 1, max: 12, onChanged: (v) => setState(() => _width = v))),
          IconButton(tooltip: 'Metin ekle', onPressed: _addText,
            icon: const Icon(Icons.text_fields)),
          IconButton(tooltip: 'Geri al', onPressed: _undo.isEmpty ? null : _undoStroke,
            icon: const Icon(Icons.undo)),
          IconButton(tooltip: 'İleri al', onPressed: _redo.isEmpty ? null : _redoStroke,
            icon: const Icon(Icons.redo)),
        ]),
    ),
  );
}
