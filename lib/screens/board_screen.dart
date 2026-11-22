import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/board_service.dart';

class BoardScreen extends StatefulWidget {
  const BoardScreen({super.key});
  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  final _service = BoardService();
  final _message = TextEditingController();
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _stream;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _stream = _service.watchMessages();
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    if (_busy || _message.text.trim().isEmpty) return;
    final text = _message.text.trim();
    final requestId = _service.newRequestId();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _service.createOnce(requestId: requestId, text: text);
      if (mounted) _message.clear();
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit(String id, String oldText) async {
    final newText = await showDialog<String>(
      context: context,
      builder: (ctx) {
        String editedText = oldText;

        return AlertDialog(
          title: const Text('Edit message'),
          content: TextFormField(
            initialValue: oldText,
            maxLength: 500,
            autofocus: true,
            onChanged: (value) => editedText = value,
            decoration: const InputDecoration(
              hintText: 'Message',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, editedText.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (!mounted || newText == null || newText.isEmpty) return;

    try {
      await _service.editMessage(id, newText);
    } catch (e) {
      if (mounted) _showError(e);
    }
  }

  Future<void> _delete(String id) async {
    final yes = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('Delete message?'),
              content: const Text('This cannot be undone.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Delete'))
              ],
            ));
    if (yes != true) return;
    try {
      await _service.deleteMessage(id);
    } catch (e) {
      if (mounted) _showError(e);
    }
  }

  void _showError(Object e) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(friendlyError(e))));

  @override
  Widget build(BuildContext context) {
    final uid = AuthService().currentUser!.uid;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Campus Board'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService().signOut();
            },
          ),
        ],
      ),
      body: Column(children: [
        Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _stream,
          builder: (context, snapshot) {
            if (snapshot.hasError)
              return Center(
                  child: Text(
                      'Could not load messages: ${friendlyError(snapshot.error!)}'));
            if (!snapshot.hasData)
              return const Center(child: CircularProgressIndicator());
            final docs = snapshot.data!.docs;
            if (docs.isEmpty)
              return const Center(
                  child: Text('No messages yet. Be the first to post!'));
            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: docs.length,
              itemBuilder: (context, i) {
                final doc = docs[i];
                final data = doc.data();
                final mine = data['authorUid'] == uid;
                final created = data['createdAt'];
                final time = created is Timestamp
                    ? created.toDate().toLocal().toString().substring(0, 16)
                    : 'Sending...';
                return Card(
                    child: ListTile(
                  title: Text(data['text'] as String? ?? ''),
                  subtitle: Text(
                      '${data['authorName'] ?? 'Member'} · $time${data['editedAt'] == null ? '' : ' · edited'}'),
                  trailing: mine
                      ? Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                              tooltip: 'Edit',
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () =>
                                  _edit(doc.id, data['text'] as String? ?? '')),
                          IconButton(
                              tooltip: 'Delete',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _delete(doc.id)),
                        ])
                      : null,
                ));
              },
            );
          },
        )),
        if (_error != null)
          Text(_error!, style: const TextStyle(color: Colors.red)),
        Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            child: Row(children: [
              Expanded(
                  child: TextField(
                      controller: _message,
                      maxLength: 500,
                      maxLines: 2,
                      minLines: 1,
                      decoration: const InputDecoration(
                          labelText: 'Write a message',
                          border: OutlineInputBorder()))),
              const SizedBox(width: 8),
              FilledButton(
                  onPressed: _busy ? null : _post,
                  child: Text(_busy ? 'Sending...' : 'Post')),
            ])),
      ]),
    );
  }
}
