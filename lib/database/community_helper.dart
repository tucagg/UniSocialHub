import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import '../screens/community/models/community_structure.dart';
import '../screens/events/models/event_structure.dart';
import 'database_helper.dart';
import 's3_service.dart';
import '../utils/image_cache_manager.dart';

class CommunityHelper {
  static final CommunityHelper _instance = CommunityHelper._internal();

  factory CommunityHelper() => _instance;

  CommunityHelper._internal();

  final _supabase = Supabase.instance.client;
  final _databaseHelper = DatabaseHelper();

  Future<void> createCommunity(Community community) async {
    try {
      final fileName = '${DateTime
          .now()
          .millisecondsSinceEpoch}_${community.name.replaceAll(' ', '_')}.jpg';
      final photoUrl = await _databaseHelper.uploadFileToS3(
          File(community.photoUrl),
          'community_images',
          fileName
      );

      if (photoUrl == null) {
        throw Exception('Fotoğraf yüklenemedi');
      }

      await _supabase.from('communities').insert({
        'name': community.name,
        'description': community.description,
        'photo_url': photoUrl,
        'members': community.members,
        'admins': community.admins,
      });
    } catch (e) {
      print('Topluluk oluşturulurken hata: $e');
      throw e;
    }
  }

  Future<List<Community>> getAllCommunities() async {
    try {
      final response = await _supabase
          .from('communities')
          .select()
          .order('created_at', ascending: false);

      return (response as List).map((data) =>
          Community(
            id: data['id'],
            name: data['name'],
            description: data['description'],
            photoUrl: data['photo_url'],
            members: List<String>.from(data['members']),
            admins: List<String>.from(data['admins']),
            events: [],
          )).toList();
    } catch (e) {
      print('Topluluklar yüklenirken hata: $e');
      throw e;
    }
  }

  Future<void> joinCommunity(String communityId, String username) async {
    try {
      // Önce topluluğu getir
      final response = await _supabase
          .from('communities')
          .select('members')
          .eq('id', communityId)
          .single();

      List<String> currentMembers = List<String>.from(response['members']);

      // Kullanıcı zaten üye mi kontrol et
      if (currentMembers.contains(username)) {
        throw Exception('Zaten bu topluluğun üyesisiniz!');
      }

      // Yeni üyeyi ekle
      currentMembers.add(username);

      // Topluluğu güncelle
      await _supabase
          .from('communities')
          .update({'members': currentMembers})
          .eq('id', communityId);
    } catch (e) {
      print('Topluluğa katılırken hata: $e');
      throw e;
    }
  }

  Future<void> leaveCommunity(String communityId, String username) async {
    try {
      final response = await _supabase
          .from('communities')
          .select('members, admins')
          .eq('id', communityId)
          .single();

      List<String> currentMembers = List<String>.from(response['members']);
      List<String> currentAdmins = List<String>.from(response['admins']);

      if (!currentMembers.contains(username)) {
        throw Exception('Bu topluluğun üyesi değilsiniz!');
      }

      if (currentAdmins.contains(username)) {
        throw Exception('Admin olduğunuz topluluktan ayrılamazsınız!');
      }

      currentMembers.remove(username);

      await _supabase
          .from('communities')
          .update({'members': currentMembers})
          .eq('id', communityId);
    } catch (e) {
      print('Topluluktan ayrılırken hata: $e');
      throw e;
    }
  }

  Future<void> updateCommunity(
    String communityId,
    String name,
    String description,
    String? newPhotoUrl,
  ) async {
    try {
      final updateData = {
        'name': name,
        'description': description,
      };
      
      if (newPhotoUrl != null) {
        // Eski fotoğrafı al
        final oldData = await _supabase
            .from('communities')
            .select('photo_url')
            .eq('id', communityId)
            .single();
            
        final oldPhotoUrl = oldData['photo_url'] as String;
        
        // Eski fotoğrafı S3'ten sil
        if (oldPhotoUrl != newPhotoUrl) {
          final oldFileName = Uri.parse(oldPhotoUrl).pathSegments.last;
          await _databaseHelper.deleteS3Object('community_images', oldFileName);
          
          // Önbellekteki eski resmi sil
          final oldCachedFile = await ImageCacheManager.getCachedImageFile(oldPhotoUrl);
          if (await oldCachedFile.exists()) {
            await oldCachedFile.delete();
          }
          
          updateData['photo_url'] = newPhotoUrl;
        }
      }
      
      await _supabase
          .from('communities')
          .update(updateData)
          .eq('id', communityId);
    } catch (e) {
      print('Topluluk güncellenirken hata: $e');
      throw Exception('Topluluk güncellenirken hata oluştu: $e');
    }
  }

  Future<void> updateCommunityMembersAndAdmins(
    String communityId,
    List<String> members,
    List<String> admins,
  ) async {
    try {
      await _supabase
          .from('communities')
          .update({
            'members': members,
            'admins': admins,
          })
          .eq('id', communityId);
    } catch (e) {
      print('Topluluk üyeleri güncellenirken hata: $e');
      throw Exception('Topluluk üyeleri güncellenirken hata oluştu: $e');
    }
  }
  Future<String?> getAdminCommunityIdForUser(String username) async {
    try {
      // Admins sütununda username içeren toplulukları filtrelemek için `contains` kullanıyoruz
      final response = await _supabase
          .from('communities')
          .select('id, admins')
          .contains('admins', [username])
          .single();

      if (response == null) {
        return null; // Kullanıcı admin olduğu bir topluluk yoksa
      }

      return response['id'] as String?;
    } catch (e) {
      print('Admin topluluk ID alınırken hata: $e');
      return null;
    }
  }

  Future<List<Event>> getCommunityEvents(String communityId) async {
    try {
      final response = await _supabase
          .from('events')
          .select()
          .eq('community_id', communityId)
          .eq('is_approved', true)
          .order('date_time', ascending: true);

      return (response as List).map((data) => Event(
        id: data['id'],
        title: data['title'],
        description: data['description'],
        dateTime: data['date_time'],
        location: data['location'],
        organizer: data['organizer'],
        imageUrl: data['image_url'],
        participants: List<String>.from(data['participants'] ?? []),
        communityId: data['community_id'],
        isApproved: data['is_approved'],
      )).toList();
    } catch (e) {
      print('Topluluk etkinlikleri yüklenirken hata: $e');
      throw e;
    }
  }
}