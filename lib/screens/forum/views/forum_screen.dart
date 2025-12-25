/*
  Bu ekran, belirli bir event'e ait forumları listeler.
  "createForum" ile yeni forum ekler, forum listesi yenilenir.
*/

import 'package:flutter/material.dart';
import '../../../database/forum_service.dart';
import '../models/forum_model.dart';
import 'topic_detail_page.dart';
import 'add_topic_dialog.dart';
import '../../events/models/event_structure.dart';

class ForumScreen extends StatefulWidget {
  final Event event;

  const ForumScreen({Key? key, required this.event}) : super(key: key);

  @override
  State<ForumScreen> createState() => _ForumScreenState();
}

class _ForumScreenState extends State<ForumScreen> {
  final ForumService _forumService = ForumService();
  bool _isLoading = true;
  List<Forum> _forums = [];

  @override
  void initState() {
    super.initState();
    _fetchForums();
  }

  Future<void> _fetchForums() async {
    setState(() => _isLoading = true);
    try {
      final forums = await _forumService.getForumsByEventId(widget.event.id!);
      setState(() {
        _forums = forums;
      });
    } catch (e) {
      print('Hata (forumları çekme): $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Forumları çekerken hata: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addNewTopic() async {
    // Dialog ile başlık + ilk mesaj içeriği alıyoruz
    final result = await showDialog(
      context: context,
      builder: (context) => const AddTopicDialog(),
    );

    if (result != null && result['title'] != '' && result['content'] != '') {
      try {
        // 1) Yeni forum oluştur
        final newForum = await _forumService.createForum(
          eventId: widget.event.id!,
          title: result['title'],
        );
        // 2) Yeni forumun ilk entry'sini ekle (başlangıç mesajı)
        await _forumService.createEntry(
          forumId: newForum.forumId,
          content: result['content'],
        );
        // 3) Listeyi yenile
        await _fetchForums();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Konu eklerken hata: $e')),
        );
      }
    } else {
      print('Konu ekleme iptal veya eksik veri.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.event.title} Forumu'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // Arama vb. eklenebilir
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addNewTopic,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _forums.isEmpty
          ? const Center(child: Text('Henüz forum yok.'))
          : ListView.separated(
        itemCount: _forums.length,
        separatorBuilder: (context, index) => const Divider(
          color: Color(0xFF02367B),
          thickness: 2,
        ),
        itemBuilder: (context, index) {
          final forum = _forums[index];
          return ListTile(
            title: Text(forum.title),
            subtitle: Text('Oluşturulma: ${forum.createdAt}'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TopicDetailPage(forum: forum),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
