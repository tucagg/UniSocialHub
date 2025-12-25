/*
  Bu dosya, Forum ve ForumEntry modellerini içerir.
  Forum: forum_id, event_id, title, created_at
  ForumEntry: entry_id, forum_id, authorEmail, content, created_at
*/

class Forum {
  final String forumId;
  final String eventId;
  final String title;
  final DateTime createdAt;

  Forum({
    required this.forumId,
    required this.eventId,
    required this.title,
    required this.createdAt,
  });

  factory Forum.fromMap(Map<String, dynamic> map) {
    return Forum(
      forumId: map['forum_id'] as String,
      eventId: map['event_id'] as String,
      title: map['title'] as String,
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}

class ForumEntry {
  final String entryId;
  final String forumId;
  final String authorEmail;  // <-- Kullanıcı e-mail
  final String content;
  final DateTime createdAt;

  ForumEntry({
    required this.entryId,
    required this.forumId,
    required this.authorEmail,
    required this.content,
    required this.createdAt,
  });

  factory ForumEntry.fromMap(Map<String, dynamic> map) {
    return ForumEntry(
      entryId: map['entry_id'] as String,
      forumId: map['forum_id'] as String,
      authorEmail: map['author_email'] as String, // <-- Tablo kolonu
      content: map['content'] as String,
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}
