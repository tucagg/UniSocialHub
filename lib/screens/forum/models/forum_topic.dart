// forum/models/forum_topic.dart

// Forumu test etmek için ForumTopic modelini ekliyorum
class ForumTopic {
  final String title;
  final String author;
  final int replies;
  final String lastUpdate;
  final String content; // Yeni eklenen alan

  ForumTopic({
    required this.title,
    required this.author,
    required this.replies,
    required this.lastUpdate,
    required this.content, // Yeni eklenen alan
  });
}
