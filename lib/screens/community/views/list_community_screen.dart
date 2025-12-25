// lib/screens/community/views/list_community_screen.dart

import 'package:flutter/material.dart';
import 'package:gtu/screens/community/views/community_screen.dart';
import '../../events/models/event_structure.dart';
import '../models/community_structure.dart'; // Community modelini içe aktarıyorum
import 'add_community_screen.dart'; // AddCommunityScreen'i içe aktarıyorum
import '../../../database/database_helper.dart'; // Düzeltilmiş import yolu
import '../../../utils/image_cache_manager.dart'; // ImageCacheManager'i içe aktarıyorum
import 'dart:typed_data';
import '../../../database/community_helper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../constants.dart';

class ListCommunityScreen extends StatefulWidget {
  const ListCommunityScreen({super.key});

  @override
  _ListCommunityScreenState createState() => _ListCommunityScreenState();
}

class _ListCommunityScreenState extends State<ListCommunityScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final CommunityHelper _communityHelper = CommunityHelper();
  final List<Community> _communities = [];
  bool _isLoading = true;
  Map<String, Uint8List?> _communityImages = {};
  String _currentUsername = '';
  bool _isAdmin = false;
  int? _userAuthorityLevel;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadCommunities();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userData = await _databaseHelper.getUserData(user.email!);
        setState(() {
          _currentUsername = userData['username'];
          _isAdmin = (userData['authority_level'] ?? 0) >= ADMIN;
        });
      }
    } catch (e) {
      print('Kullanıcı bilgileri yüklenirken hata: $e');
    }
  }

  Future<void> _loadCommunityImage(String photoUrl) async {
    try {
      final cachedImage = await ImageCacheManager.getCachedImage(photoUrl);
      if (cachedImage != null) {
        setState(() {
          _communityImages[photoUrl] = cachedImage;
        });
        return;
      }

      final imageBytes = await _databaseHelper.getImageFromS3(photoUrl);
      if (imageBytes != null) {
        await ImageCacheManager.cacheImage(photoUrl, imageBytes);
        setState(() {
          _communityImages[photoUrl] = imageBytes;
        });
      }
    } catch (e) {
      print('Topluluk resmi yüklenirken hata: $e');
    }
  }

  Future<void> _loadCommunities() async {
    try {
      final communities = await _communityHelper.getAllCommunities();
      setState(() {
        _communities.clear();
        _communities.addAll(communities);
        _isLoading = false;
      });

      // Topluluk resimleri yükle
      for (var community in communities) {
        _loadCommunityImage(community.photoUrl);
      }
    } catch (e) {
      print('Topluluklar yüklenirken hata: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Topluluklar yüklenirken hata oluştu: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _joinCommunity(Community community) async {
    final user = FirebaseAuth.instance.currentUser;
    
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen önce giriş yapın')),
      );
      return;
    }

    if (!user.emailVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen önce email adresinizi doğrulayın')),
      );
      return;
    }

    if (_currentUsername == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen önce kullanıcı adınızı belirleyin')),
      );
      return;
    }

    try {
      await _communityHelper.joinCommunity(community.id, _currentUsername!);
      await _loadCommunities();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${community.name} topluluğuna başarıyla katıldınız')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Topluluğa katılırken bir hata oluştu: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Topluluklar'),
        actions: [
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Yeni Topluluk Ekle',
              onPressed: () async {
                final newCommunity = await Navigator.push<Community>(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddCommunityScreen(),
                  ),
                );

                if (newCommunity != null) {
                  setState(() {
                    _communities.add(newCommunity);
                  });
                }
              },
            ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _communities.isEmpty
                ? const Center(
                    child: Text(
                      'Henüz bir topluluk eklenmedi.',
                      style: TextStyle(fontSize: 16.0),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: _communities.length,
                    itemBuilder: (context, index) {
                      final community = _communities[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 16.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        elevation: 4.0,
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16.0),
                          leading: CircleAvatar(
                            radius: 30,
                            backgroundColor: Colors.blueAccent,
                            backgroundImage: _communityImages[community.photoUrl] != null
                                ? MemoryImage(_communityImages[community.photoUrl]!)
                                : null,
                            child: _communityImages[community.photoUrl] == null
                                ? const Icon(
                                    Icons.group,
                                    color: Colors.white,
                                    size: 24,
                                  )
                                : null,
                          ),
                          title: Text(
                            community.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18.0,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 8.0),
                              Text(
                                community.description,
                                style: const TextStyle(
                                  fontSize: 14.0,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4.0),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.group,
                                    size: 16.0,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 4.0),
                                  Expanded(
                                    child: Text(
                                      'Üyeler: ${community.members.join(', ')}',
                                      style: const TextStyle(
                                        fontSize: 14.0,
                                        color: Colors.grey,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8.0),
                              ElevatedButton(
                                onPressed: community.members.contains(_currentUsername) 
                                    ? null  // Eğer kullanıcı zaten üyeyse butonu devre dışı bırak
                                    : () => _joinCommunity(community),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 12.0),
                                  textStyle: const TextStyle(fontSize: 12.0),
                                ),
                                child: Text(
                                  community.members.contains(_currentUsername) ? 'Katıldınız' : 'Katıl'
                                ),
                              ),
                            ],
                          ),
                          onTap: () async {
                            final needsRefresh = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CommunityScreen(community: community),
                              ),
                            );

                            // Eğer güncelleme yapıldıysa topluluk listesini yenile
                            if (needsRefresh == true) {
                              _loadCommunities();
                            }
                          },
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}