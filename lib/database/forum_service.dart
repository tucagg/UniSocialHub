/*
  Bu dosya, Supabase ile forum CRUD işlemlerini yapar:
  - Forum oluşturma
  - Forumları eventId'ye göre listeleme
  - Forum'u silme
  - Entry (yorum) ekleme
  - Entry'leri forumId'ye göre listeleme

  Artık "author_uid" yerine "author_email" kullanıyoruz.
*/

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/forum/models/forum_model.dart';

class ForumService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // 1) Yeni forum oluştur
  Future<Forum> createForum({
    required String eventId,
    required String title,
  }) async {
    final response = await _supabase
        .from('forums')
        .insert({
      'event_id': eventId,
      'title': title,
    })
        .select()
        .single();

    final data = response;
    return Forum.fromMap(data);
  }

  // 2) Bir event'e ait tüm forumları listele
  Future<List<Forum>> getForumsByEventId(String eventId) async {
    final response = await _supabase
        .from('forums')
        .select('*')
        .eq('event_id', eventId)
        .order('created_at', ascending: false);

    final List<dynamic> data = response;
    return data.map((map) => Forum.fromMap(map)).toList();
  }

  // 3) Forum'u sil
  Future<void> deleteForum(String forumId) async {
    await _supabase
        .from('forums')
        .delete()
        .eq('forum_id', forumId);
  }

  // 4) Forum'a entry (yorum) ekle
  Future<ForumEntry> createEntry({
    required String forumId,
    required String content,
  }) async {
    // Kullanıcının e-mail adresini alıyoruz
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Kullanıcı oturumu yok!');
    }
    final email = user.email;
    if (email == null) {
      throw Exception('Kullanıcının e-mail adresi bulunamadı!');
    }

    final response = await _supabase
        .from('forum_entries')
        .insert({
      'forum_id': forumId,
      'author_email': email, // <-- email
      'content': content,
    })
        .select()
        .single();

    final data = response;
    return ForumEntry.fromMap(data);
  }

  // 5) Bir forum'a ait tüm entry'leri listele
  Future<List<ForumEntry>> getEntriesByForumId(String forumId) async {
    final response = await _supabase
        .from('forum_entries')
        .select('*')
        .eq('forum_id', forumId)
        .order('created_at', ascending: false);

    final List<dynamic> data = response;
    return data.map((map) => ForumEntry.fromMap(map)).toList();
  }
}
