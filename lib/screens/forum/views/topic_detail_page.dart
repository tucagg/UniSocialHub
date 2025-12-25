/*
  Bu ekran, bir forumun (konunun) detaylarını ve yorumlarını (forum_entries) gösterir.
  Yorum (entry) ekleme fonksiyonunu da içerir.
  Artık "authorEmail" bilgisini gösteriyoruz.
*/

import 'package:flutter/material.dart';
import '../../../database/forum_service.dart';
import '../models/forum_model.dart';

class TopicDetailPage extends StatefulWidget {
  final Forum forum;

  const TopicDetailPage({Key? key, required this.forum}) : super(key: key);

  @override
  State<TopicDetailPage> createState() => _TopicDetailPageState();
}

class _TopicDetailPageState extends State<TopicDetailPage> {
  final ForumService _forumService = ForumService();
  final TextEditingController _commentController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  List<ForumEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _fetchEntries();
  }

  Future<void> _fetchEntries() async {
    setState(() => _isLoading = true);
    try {
      final entries = await _forumService.getEntriesByForumId(widget.forum.forumId);
      setState(() => _entries = entries);
    } catch (e) {
      print('Yorumları çekerken hata: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Yorumları çekerken hata: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addComment() async {
    if (_formKey.currentState!.validate()) {
      try {
        await _forumService.createEntry(
          forumId: widget.forum.forumId,
          content: _commentController.text,
        );
        _commentController.clear();
        await _fetchEntries(); // Listeyi yenile
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Yorum eklerken hata: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.forum.title),
      ),
      body: Column(
        children: [
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: _entries.isEmpty
                  ? const Center(child: Text('Henüz yorum yok.'))
                  : ListView.separated(
                itemCount: _entries.length,
                separatorBuilder: (context, index) => const Divider(
                  color: Color(0xFF02367B),
                  thickness: 1.0,
                ),
                itemBuilder: (context, index) {
                  final entry = _entries[index];
                  return ListTile(
                    title: Text('Yazar e-mail: ${entry.authorEmail}'),
                    subtitle: Text(entry.content),
                    trailing: Text(
                      '${entry.createdAt.hour}:${entry.createdAt.minute}',
                    ),
                  );
                },
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Form(
                key: _formKey,
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _commentController,
                        decoration: const InputDecoration(
                          hintText: 'Yorum yaz...',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Yorum boş olamaz!';
                          }
                          return null;
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: _addComment,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
