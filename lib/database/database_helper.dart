import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import '../screens/community/models/community_structure.dart';
import 's3_service.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  late final SupabaseClient _supabase;
  bool _isInitialized = false;

  Future<void> init() async {
    if (!_isInitialized) {
      await Supabase.initialize(
        url: 'https://uajsshlbfppjjytmugls.supabase.co',
        anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVhanNzaGxiZnBwamp5dG11Z2xzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzAwNDIyNzYsImV4cCI6MjA0NTYxODI3Nn0.yoo-iawGN9MpdlSAveyZSUMDb5eGDz7Bz_DvLvKsvKE',
      );
      _supabase = Supabase.instance.client;
      _isInitialized = true;
    }
  }

  Future<void> addUser(String email, String username) async {
    try {
      await _supabase.from('users').insert({
        'email': email,
        'username': username,
        'disabled': false,
        'registration_timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Kullanıcı eklenirken hata: $e');
      throw e;
    }
  }

  Future<void> updateEmailVerificationStatus(String email, bool isVerified) async {
    try {
      await _supabase
          .from('users')
          .update({'email_verified': isVerified})
          .eq('email', email);
    } catch (e) {
      print('Email doğrulama durumu güncellenirken hata: $e');
      throw e;
    }
  }

  Future<void> updateUserDetails(String email, String username, int entryYear, String department) async {
    try {
      await _supabase.from('users').update({
        'username': username,
        'entry_year': entryYear,
        'department': department,
      }).eq('email', email);
    } catch (e) {
      print('Kullanıcı detayları güncellenirken hata: $e');
      throw e;
    }
  }

  Future<bool> isUsernameTaken(String username) async {
    try {
      final response = await _supabase
          .from('users')
          .select('username')
          .eq('username', username)
          .single();
      return response != null;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>> getUserData(String email) async {
    try {
      final response = await _supabase
          .from('users')
          .select()
          .eq('email', email)
          .single();
      
      return {
        'username': response['username'],
        'profile_image_url': response['profile_image_url'],
        'first_name': response['first_name'],
        'last_name': response['last_name'],
        'entry_year': response['entry_year'],
        'department': response['department'],
        'authority_level': response['authority_level'],
        'disabled': response['disabled'],
      };
    } catch (e) {
      print('Kullanıcı verileri alınırken hata: $e');
      throw Exception('Kullanıcı bulunamadı');
    }
  }

  Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      final response = await _supabase
          .from('users')
          .select()
          .order('registration_timestamp', ascending: false);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Tüm kullanıcılar alınırken hata: $e');
      return [];
    }
  }

  Future<void> updateUserAuthority(String email, int authorityLevel) async {
    try {
      await _supabase
          .from('users')
          .update({'authority_level': authorityLevel})
          .eq('email', email);
    } catch (e) {
      print('Kullanıcı yetkisi güncellenirken hata: $e');
      throw e;
    }
  }

  Future<void> updateUserDisabledStatus(String email, bool disabled) async {
    try {
      await _supabase
          .from('users')
          .update({'disabled': disabled})
          .eq('email', email);
    } catch (e) {
      print('Kullanıcı durumu güncellenirken hata: $e');
      throw e;
    }
  }
 Future<void> updateProfileImageUrl(String email, String imageUrl) async {
    try {
      await _supabase
          .from('users')
          .update({'profile_image_url': imageUrl})
          .eq('email', email);
    } catch (e) {
      print('Profil resmi URL\'si güncellenirken hata: $e');
      throw e;
    }
  }

  Future<void> updateUserNames(String email, String firstName, String lastName) async {
    try {
      await _supabase
          .from('users')
          .update({
            'first_name': firstName,
            'last_name': lastName,
          })
          .eq('email', email);
    } catch (e) {
      print('Kullanıcı isimleri güncellenirken hata: $e');
      throw e;
    }
  }

  Future<void> updateUsernameAndProfileImage(String email, String username, String? profileImageUrl) async {
    try {
      // Önce eski kullanıcı adını al
      var userData = await getUserData(email);
      String oldUsername = userData['username'];

      // Kullanıcı adının kullanılabilir olup olmadığını kontrol et
      bool usernameExists = await isUsernameTaken(username);
      if (usernameExists) {
        throw Exception('Bu kullanıcı adı zaten kullanımda.');
      }

      String? oldFileName;
      String? newFileName;
      String? newImageUrl;

      if (profileImageUrl != null) {
        oldFileName = Uri.parse(profileImageUrl).pathSegments.last;
        final fileExtension = oldFileName.split('.').last;
        newFileName = '${username}_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
        await S3Service().renameObject('profile_images', oldFileName, newFileName);
        newImageUrl = S3Service().getS3Url('profile_images', newFileName);
      }

      // Users tablosunu güncelle
      if (newImageUrl != null) {
        await _supabase
            .from('users')
            .update({
              'username': username,
              'profile_image_url': newImageUrl,
            })
            .eq('email', email);
      } else {
        await _supabase
            .from('users')
            .update({'username': username})
            .eq('email', email);
      }

      // Communities tablosundaki members listelerini güncelle
      final communities = await _supabase
          .from('communities')
          .select('id, members')
          .contains('members', [oldUsername]);

      for (var community in communities) {
        List<String> members = List<String>.from(community['members']);
        int index = members.indexOf(oldUsername);
        if (index != -1) {
          members[index] = username;
          await _supabase
              .from('communities')
              .update({'members': members})
              .eq('id', community['id']);
        }
      }

      // Communities tablosundaki admins listelerini güncelle
      final adminCommunities = await _supabase
          .from('communities')
          .select('id, admins')
          .contains('admins', [oldUsername]);

      for (var community in adminCommunities) {
        List<String> admins = List<String>.from(community['admins']);
        int index = admins.indexOf(oldUsername);
        if (index != -1) {
          admins[index] = username;
          await _supabase
              .from('communities')
              .update({'admins': admins})
              .eq('id', community['id']);
        }
      }

      // Events tablosundaki participants listelerini güncelle
      final events = await _supabase
          .from('events')
          .select('id, participants')
          .contains('participants', [oldUsername]);

      for (var event in events) {
        List<String> participants = List<String>.from(event['participants'] ?? []);
        int index = participants.indexOf(oldUsername);
        if (index != -1) {
          participants[index] = username;
          await _supabase
              .from('events')
              .update({'participants': participants})
              .eq('id', event['id']);
        }
      }

      // Events tablosundaki organizer alanını güncelle
      await _supabase
          .from('events')
          .update({'organizer': username})
          .eq('organizer', oldUsername);

    } catch (e) {
      print('Kullanıcı adı ve profil resmi güncellenirken hata: $e');
      throw e;
    }
  }

  Future<void> updateUserInfo(String email, Map<String, dynamic> data) async {
    try {
      await _supabase
          .from('users')
          .update(data)
          .eq('email', email);
    } catch (e) {
      print('Kullanıcı bilgileri güncellenirken hata: $e');
      throw e;
    }
  }
  
  Future<void> deleteUserAndProfileImage(String email) async {
    try {
      var userData = await getUserData(email);
      String? profileImageUrl = userData['profile_image_url'];

      if (profileImageUrl != null) {
        final fileName = Uri.parse(profileImageUrl).pathSegments.last;
        await S3Service().deleteObject('profile_images', fileName);
      }

      await _supabase
          .from('users')
          .delete()
          .eq('email', email);
    } catch (e) {
      print('Kullanıcı ve profil resmi silinirken hata: $e');
      throw e;
    }
  }

  // S3 işlemleri için yardımcı metodlar aynı kalabilir
  Future<String?> uploadFileToS3(File file, String folderPath, String fileName) async {
    return await S3Service().uploadFile(file, folderPath, fileName);
  }

  Future<void> deleteS3Object(String folderPath, String fileName) async {
    await S3Service().deleteObject(folderPath, fileName);
  }

  Future<Uint8List?> getImageFromS3(String imageUrl) async {
    final uri = Uri.parse(imageUrl);
    final folderPath = uri.pathSegments[uri.pathSegments.length - 2];
    final fileName = uri.pathSegments.last;
    return await S3Service().getFile(folderPath, fileName);
  }
}
