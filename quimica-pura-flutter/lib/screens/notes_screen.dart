// Mi cuaderno (v5): notas propias del usuario, una por tema (y una
// general), guardadas en el teléfono. Sin internet.

import 'package:flutter/material.dart';
import '../widgets/lucide_icons.dart';

import '../data/topics.dart';
import '../services/localization.dart';
import '../services/notes.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});
  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  @override
  Widget build(BuildContext context) {
    final all = <(String, String)>[
      ('general', 'Nota general'),
      for (final t in [...topics, ...branchTopics]) (t.slug, t.title),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(tr('notesTitle'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Escribe tus propias notas en cada tema. Se guardan en el teléfono.',
          ),
          const SizedBox(height: 12),
          for (final (slug, title) in all)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 2,
              shadowColor:
                  const Color(0xFF00C2A8).withValues(alpha: 0.15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                leading: LucideIcon(
                  NotesService.instance.hasNote(slug)
                      ? LucideIcons.notebookPen
                      : LucideIcons.pencil,
                ),
                title: Text(title,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: NotesService.instance.hasNote(slug)
                    ? Text(
                        NotesService.instance.noteFor(slug),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      )
                    : const Text('Sin nota todavía'),
                trailing: const LucideIcon(LucideIcons.chevronRight),
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => _NoteEditPage(slug: slug, title: title)),
                  );
                  setState(() {});
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _NoteEditPage extends StatefulWidget {
  const _NoteEditPage({required this.slug, required this.title});
  final String slug;
  final String title;

  @override
  State<_NoteEditPage> createState() => _NoteEditPageState();
}

class _NoteEditPageState extends State<_NoteEditPage> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
        text: NotesService.instance.noteFor(widget.slug));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: 'Guardar',
            icon: const LucideIcon(LucideIcons.save),
            onPressed: () {
              NotesService.instance.saveNote(widget.slug, _ctrl.text);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          controller: _ctrl,
          maxLines: null,
          expands: true,
          textAlignVertical: TextAlignVertical.top,
          decoration: const InputDecoration(
            hintText: 'Escribe tu nota aquí…',
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }
}
