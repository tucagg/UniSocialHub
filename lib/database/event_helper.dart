import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'database_helper.dart';
import '../screens/events/models/event_structure.dart';

class EventHelper {
  static final EventHelper _instance = EventHelper._internal();
  factory EventHelper() => _instance;
  EventHelper._internal();

  final _supabase = Supabase.instance.client;
  final _databaseHelper = DatabaseHelper();

  // Etkinlik oluşturma
  Future<Event?> addEvent({
    required String title,
    required String description,
    required String dateTime,
    required String location,
    required String organizer,
    required String communityId,
    File? imageFile,
    bool isApproved = false, // Onay durumu varsayılan olarak false
  }) async {
    try {
      String? imageUrl;

      // Eğer bir dosya seçilmişse yükleme işlemi yapılır
      if (imageFile != null && imageFile.existsSync()) {
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${title.replaceAll(' ', '_')}.jpg';

        // Görseli S3'e yükle
        imageUrl = await _databaseHelper.uploadFileToS3(
          imageFile,
          'event_images', // Bucket adı
          fileName,
        );

        if (imageUrl == null) {
          throw Exception('Görsel yüklenemedi');
        }
      }

      // Etkinlik bilgilerini Supabase'e ekle
      final response = await _supabase
          .from('events')
          .insert({
            'title': title,
            'description': description,
            'date_time': dateTime,
            'location': location,
            'organizer': organizer,
            'image_url': imageUrl ?? '',
            'participants': [],
            'community_id': communityId,
            'is_approved': isApproved, // Etkinlik onay durumu
          })
          .select()
          .single();

      // Yeni eklenen etkinlik bilgilerini dön
      return Event(
        id: response['id'] as String?,
        title: response['title'] as String,
        description: response['description'] as String,
        dateTime: response['date_time'] as String,
        location: response['location'] as String,
        organizer: response['organizer'] as String,
        imageUrl: response['image_url'] as String,
        participants: [],
        communityId: response['community_id'] as String,
        isApproved: response['is_approved'] as bool,
      );
    } catch (e) {
      print('Etkinlik oluşturulurken hata: $e');
      throw e;
    }
  }

  // Tüm etkinlikleri getir
  Future<List<Event>> getAllEvents() async {
    try {
      final response = await _supabase
          .from('events')
          .select()
          .order('date_time', ascending: true);

      // Gelen yanıtı `Event` nesnelerine dönüştür
      return (response as List).map((data) {
        return Event(
          id: data['id'] as String?,
          title: data['title'] as String,
          description: data['description'] as String,
          dateTime: data['date_time'] as String,
          location: data['location'] as String,
          organizer: data['organizer'] as String,
          imageUrl: data['image_url'] as String,
          participants: List<String>.from(data['participants'] ?? []),
          communityId: data['community_id'] as String,
          isApproved: data['is_approved'] as bool,
        );
      }).toList();
    } catch (e) {
      print('Etkinlikler alınırken hata: $e');
      throw e;
    }
  }

  // Kullanıcının otorite seviyesine göre etkinlikleri getir
  Future<List<Event>> getEventsBasedOnAuthority(
      {required int currentAuthorityLevel}) async {
    try {
      final response = await _supabase
          .from('events')
          .select()
          .order('date_time', ascending: true); // Order by date_time ascending

      if (response == null || response.isEmpty) {
        return [];
      }

      final List<Event> events = [];

      for (final event in response as List<dynamic>) {
        final eventMap = event as Map<String, dynamic>;

        // Skip unapproved events entirely
        if (!(eventMap['is_approved'] as bool)) {
          continue;
        }

        events.add(Event(
          id: eventMap['id'] as String?,
          title: eventMap['title'] as String,
          description: eventMap['description'] as String,
          dateTime: eventMap['date_time'] as String,
          location: eventMap['location'] as String,
          organizer: eventMap['organizer'] as String,
          imageUrl: eventMap['image_url'] as String,
          participants: List<String>.from(eventMap['participants'] ?? []),
          communityId: eventMap['community_id'] as String,
          isApproved: eventMap['is_approved'] as bool,
        ));
      }

      return events;
    } catch (e) {
      print('Etkinlikler alınırken hata: $e');
      throw Exception('Etkinlikler alınırken hata oluştu: $e');
    }
  }

  // Onaylanmamış etkinlikleri getir
  Future<List<Event>> getUnapprovedEvents() async {
    try {
      final response =
          await _supabase.from('events').select().eq('is_approved', false);

      // Gelen yanıtı `Event` nesnelerine dönüştür
      return (response as List).map((data) {
        return Event(
          id: data['id'] as String?,
          title: data['title'] as String,
          description: data['description'] as String,
          dateTime: data['date_time'] as String,
          location: data['location'] as String,
          organizer: data['organizer'] as String,
          imageUrl: data['image_url'] as String,
          participants: List<String>.from(data['participants'] ?? []),
          communityId: data['community_id'] as String,
          isApproved: data['is_approved'] as bool,
        );
      }).toList();
    } catch (e) {
      print('Onaylanmamış etkinlikler alınırken hata: $e');
      throw e;
    }
  }

  // Etkinlik onay durumunu güncelle
  Future<void> updateEventApproval(String eventId, bool approve) async {
    try {
      await _supabase
          .from('events')
          .update({'is_approved': approve}).eq('id', eventId);
    } catch (e) {
      print('Etkinlik onay durumu güncellenirken hata: $e');
      throw e;
    }
  }

  // Etkinliği sil
  Future<void> deleteEvent(String eventId) async {
    try {
      await _supabase.from('events').delete().eq('id', eventId);
    } catch (e) {
      print('Etkinlik silinirken hata: $e');
      throw e;
    }
  }

  // Check if user is participant
  Future<bool> isUserParticipant(String eventId, String username) async {
    try {
      final response = await _supabase
          .from('events')
          .select('participants')
          .eq('id', eventId)
          .single();

      final participants = List<String>.from(response['participants'] ?? []);
      return participants.contains(username);
    } catch (e) {
      print('Participant check error: $e');
      throw e;
    }
  }

  // Add participant to event
  Future<void> addParticipant(String eventId, String username) async {
    try {
      // Get current participants
      final response = await _supabase
          .from('events')
          .select('participants')
          .eq('id', eventId)
          .single();

      final participants = List<String>.from(response['participants'] ?? []);

      // Add new participant if not already present
      if (!participants.contains(username)) {
        participants.add(username);

        // Update the database
        await _supabase
            .from('events')
            .update({'participants': participants}).eq('id', eventId);
      }
    } catch (e) {
      print('Add participant error: $e');
      throw e;
    }
  }

  // Remove participant from event
  Future<void> removeParticipant(String eventId, String username) async {
    try {
      // Get current participants
      final response = await _supabase
          .from('events')
          .select('participants')
          .eq('id', eventId)
          .single();

      final participants = List<String>.from(response['participants'] ?? []);

      // Remove participant if present
      if (participants.contains(username)) {
        participants.remove(username);

        // Update the database
        await _supabase
            .from('events')
            .update({'participants': participants}).eq('id', eventId);
      }
    } catch (e) {
      print('Remove participant error: $e');
      throw e;
    }
  }

  // Etkinlik güncelleme
  Future<void> updateEvent({
    required String id,
    required String title,
    required String description,
    required String dateTime,
    required String location,
    File? imageFile,
  }) async {
    try {
      String? imageUrl;

      // Eğer bir dosya seçilmişse yükleme işlemi yapılır
      if (imageFile != null && imageFile.existsSync()) {
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${title.replaceAll(' ', '_')}.jpg';

        // Görseli S3'e yükle
        imageUrl = await _databaseHelper.uploadFileToS3(
          imageFile,
          'event_images', // Bucket adı
          fileName,
        );

        if (imageUrl == null) {
          throw Exception('Görsel yüklenemedi');
        }
      }

      // Etkinlik bilgilerini Supabase'de güncelle
      await _supabase.from('events').update({
        'title': title,
        'description': description,
        'date_time': dateTime,
        'location': location,
        if (imageUrl != null) 'image_url': imageUrl,
      }).eq('id', id);
    } catch (e) {
      print('Etkinlik güncellenirken hata: $e');
      throw e;
    }
  }
}
