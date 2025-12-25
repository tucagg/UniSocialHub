// lib/screens/community/views/community_screen.dart

import 'package:flutter/material.dart';
import '../../events/models/event_structure.dart';
import '../models/community_structure.dart'; // Community modelini içe aktarıyorum
import '../../../utils/image_cache_manager.dart';
import '../../../database/community_helper.dart';
import '../../../database/database_helper.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../../../database/s3_service.dart';
import 'package:intl/intl.dart';
import '../../events/views/event_details.dart';

class CommunityScreen extends StatefulWidget {
  final Community community;
  //add someEvent to test ForumScreen

  const CommunityScreen({Key? key, required this.community}) : super(key: key);

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final _databaseHelper = DatabaseHelper();
  final _communityHelper = CommunityHelper();
  String? _currentUsername;
  bool _isLoading = true;
  Uint8List? _communityImageBytes;
  int _userAuthorityLevel = 0;
  List<Event> _communityEvents = [];
  final Map<String, Uint8List?> _eventImages = {};

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
    _loadCommunityImage();
    _loadCommunityEvents();
  }

  Future<void> _getCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final userData = await _databaseHelper.getUserData(user.email!);
        setState(() {
          _currentUsername = userData['username'];
          _userAuthorityLevel = userData['authority_level'] ?? 0;
        });
      } catch (e) {
        print('Kullanıcı bilgileri alınırken hata: $e');
      }
    }
  }

  Future<void> _leaveCommunity() async {
    if (_currentUsername == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen önce giriş yapın')),
      );
      return;
    }

    try {
      await _communityHelper.leaveCommunity(widget.community.id, _currentUsername!);
      
      // Topluluğu yeniden yükle
      final updatedCommunities = await _communityHelper.getAllCommunities();
      final updatedCommunity = updatedCommunities.firstWhere(
        (c) => c.id == widget.community.id,
      );
      
      setState(() {
        widget.community.members.clear();
        widget.community.members.addAll(updatedCommunity.members);
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${widget.community.name} topluluğundan ayrıldınız')),
      );
      
      // Ana sayfaya dön ve güncelleme için true değeri döndür
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Topluluktan ayrılırken bir hata oluştu: $e')),
      );
    }
  }

  Future<void> _loadCommunityImage() async {
    try {
      final cachedFile = await ImageCacheManager.getCachedImageFile(widget.community.photoUrl);
      if (await cachedFile.exists()) {
        setState(() {
          _communityImageBytes = cachedFile.readAsBytesSync();
          _isLoading = false;
        });
        return;
      }

      final imageBytes = await _databaseHelper.getImageFromS3(widget.community.photoUrl);
      if (imageBytes != null) {
        await ImageCacheManager.cacheImage(widget.community.photoUrl, imageBytes);
        setState(() {
          _communityImageBytes = imageBytes;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Topluluk resmi yüklenirken hata: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCommunityEvents() async {
    try {
      final events = await _communityHelper.getCommunityEvents(widget.community.id);
      
      // Etkinlik resimlerini yükle
      for (final event in events) {
        if (event.imageUrl.isNotEmpty) {
          final Uint8List? cachedImage =
              await ImageCacheManager.getCachedImage(event.imageUrl);

          if (cachedImage != null) {
            _eventImages[event.id!] = cachedImage;
          } else {
            final Uint8List? imageBytes =
                await _databaseHelper.getImageFromS3(event.imageUrl);
            if (imageBytes != null) {
              await ImageCacheManager.cacheImage(event.imageUrl, imageBytes);
              _eventImages[event.id!] = imageBytes;
            }
          }
        }
      }

      setState(() {
        _communityEvents = events;
      });
    } catch (e) {
      print('Etkinlikler yüklenirken hata: $e');
    }
  }

  String _formatDateTime(String dateTime) {
    try {
      final DateTime parsedDateTime = DateTime.parse(dateTime);
      final DateFormat formatter = DateFormat('dd MMMM yyyy, HH:mm');
      return formatter.format(parsedDateTime);
    } catch (e) {
      print('Tarih formatlama hatası: $e');
      return dateTime;
    }
  }

  void _showEditDialog() {
    final nameController = TextEditingController(text: widget.community.name);
    final descriptionController = TextEditingController(text: widget.community.description);
    File? newImage;
    bool hasNewImage = false;
    Uint8List? previewImageBytes;
    Set<String> selectedMembers = Set.from(widget.community.members);
    Set<String> selectedAdmins = Set.from(widget.community.admins);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          contentPadding: const EdgeInsets.all(24),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Topluluğu Düzenle',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: GestureDetector(
                      onTap: () async {
                        final picker = ImagePicker();
                        final pickedFile = await picker.pickImage(source: ImageSource.gallery);
                        
                        if (pickedFile != null) {
                          // Resmi düzenleme
                          final croppedFile = await ImageCropper().cropImage(
                            sourcePath: pickedFile.path,
                            aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
                            compressFormat: ImageCompressFormat.jpg,
                            compressQuality: 90,
                            uiSettings: [
                              AndroidUiSettings(
                                toolbarTitle: 'Resmi Düzenle',
                                toolbarColor: Theme.of(context).primaryColor,
                                toolbarWidgetColor: Colors.white,
                                initAspectRatio: CropAspectRatioPreset.square,
                                lockAspectRatio: true,
                                cropFrameColor: Theme.of(context).primaryColor,
                                cropGridColor: Colors.transparent,
                                showCropGrid: false,
                                cropFrameStrokeWidth: 4,
                              ),
                              IOSUiSettings(
                                title: 'Resmi Düzenle',
                                aspectRatioLockEnabled: true,
                                aspectRatioPickerButtonHidden: true,
                                resetAspectRatioEnabled: false,
                                rotateButtonsHidden: true,
                                aspectRatioLockDimensionSwapEnabled: false,
                                rectX: 1.0,
                                rectY: 1.0,
                                rectWidth: 1.0,
                                rectHeight: 1.0,
                                minimumAspectRatio: 1.0,
                              ),
                            ],
                          );

                          if (croppedFile != null) {
                            final imageBytes = await croppedFile.readAsBytes();
                            setState(() {
                              newImage = File(croppedFile.path);
                              previewImageBytes = imageBytes;
                              hasNewImage = true;
                            });
                          }
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ],
                          image: hasNewImage && previewImageBytes != null
                              ? DecorationImage(
                                  image: MemoryImage(previewImageBytes!),
                                  fit: BoxFit.cover,
                                )
                              : _communityImageBytes != null
                                  ? DecorationImage(
                                      image: MemoryImage(_communityImageBytes!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                        ),
                        child: !hasNewImage && _communityImageBytes == null
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.add_photo_alternate, size: 50, color: Colors.grey),
                                  SizedBox(height: 8),
                                  Text(
                                    'Fotoğraf Seç',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ],
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Topluluk Adı',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    decoration: InputDecoration(
                      labelText: 'Açıklama',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: const Text('Üyeler'),
                    subtitle: Text(selectedMembers.isEmpty 
                        ? 'Henüz üye seçilmedi' 
                        : selectedMembers.join(', ')),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () async {
                        final users = await _databaseHelper.getAllUsers();
                        final Set<String> tempSelectedMembers = Set.from(selectedMembers);
                        
                        await showDialog(
                          context: context,
                          builder: (context) => StatefulBuilder(
                            builder: (context, setDialogState) => AlertDialog(
                              title: const Text('Üyeleri Düzenle'),
                              content: SizedBox(
                                width: double.maxFinite,
                                height: 300,
                                child: ListView.builder(
                                  itemCount: users.length,
                                  itemBuilder: (context, index) {
                                    final user = users[index];
                                    final username = user['username'] as String;
                                    return CheckboxListTile(
                                      title: Text(username),
                                      value: tempSelectedMembers.contains(username),
                                      onChanged: (bool? value) {
                                        setDialogState(() {
                                          if (value == true) {
                                            tempSelectedMembers.add(username);
                                          } else {
                                            tempSelectedMembers.remove(username);
                                          }
                                        });
                                      },
                                    );
                                  },
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('İptal'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      selectedMembers.clear();
                                      selectedMembers.addAll(tempSelectedMembers);
                                    });
                                    Navigator.pop(context);
                                  },
                                  child: const Text('Tamam'),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: const Text('Adminler'),
                    subtitle: Text(selectedAdmins.isEmpty 
                        ? 'Henüz admin seçilmedi' 
                        : selectedAdmins.join(', ')),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () async {
                        final users = await _databaseHelper.getAllUsers();
                        final adminUsers = users.where((user) => 
                          (user['authority_level'] ?? 0) >= 1
                        ).toList();
                        final Set<String> tempSelectedAdmins = Set.from(selectedAdmins);
                        
                        await showDialog(
                          context: context,
                          builder: (context) => StatefulBuilder(
                            builder: (context, setDialogState) => AlertDialog(
                              title: const Text('Adminleri Düzenle'),
                              content: SizedBox(
                                width: double.maxFinite,
                                height: 300,
                                child: ListView.builder(
                                  itemCount: adminUsers.length,
                                  itemBuilder: (context, index) {
                                    final user = adminUsers[index];
                                    final username = user['username'] as String;
                                    return CheckboxListTile(
                                      title: Text(username),
                                      value: tempSelectedAdmins.contains(username),
                                      onChanged: (bool? value) {
                                        if (value == false && tempSelectedAdmins.length <= 1 && tempSelectedAdmins.contains(username)) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('En az bir admin olmalıdır!'),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                          return;
                                        }
                                        
                                        setDialogState(() {
                                          if (value == true) {
                                            tempSelectedAdmins.add(username);
                                          } else {
                                            tempSelectedAdmins.remove(username);
                                          }
                                        });
                                      },
                                    );
                                  },
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('İptal'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      selectedAdmins.clear();
                                      selectedAdmins.addAll(tempSelectedAdmins);
                                    });
                                    Navigator.pop(context);
                                  },
                                  child: const Text('Tamam'),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  // Admin kontrolü
                  if (selectedAdmins.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('En az bir admin seçmelisiniz!'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                  
                  String? newPhotoUrl;
                  
                  // Eğer yeni resim seçildiyse
                  if (newImage != null) {
                    final sanitizedName = nameController.text.replaceAll(' ', '_');
                    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${sanitizedName}.jpg';
                    newPhotoUrl = await _databaseHelper.uploadFileToS3(
                      newImage!,
                      'community_images',
                      fileName,
                    );
                    
                    if (newPhotoUrl == null) {
                      throw Exception('Fotoğraf yüklenemedi');
                    }
                  } 
                  // Sadece isim değişikliği varsa ve fotoğraf varsa
                  else if (widget.community.name != nameController.text && widget.community.photoUrl.isNotEmpty) {
                    final oldFileName = Uri.parse(widget.community.photoUrl).pathSegments.last;
                    final sanitizedName = nameController.text.replaceAll(' ', '_');
                    final newFileName = '${DateTime.now().millisecondsSinceEpoch}_${sanitizedName}.jpg';
                    
                    await S3Service().renameObject('community_images', oldFileName, newFileName);
                    newPhotoUrl = S3Service().getS3Url('community_images', newFileName);
                  }

                  await _communityHelper.updateCommunity(
                    widget.community.id,
                    nameController.text,
                    descriptionController.text,
                    newPhotoUrl,
                  );

                  await _communityHelper.updateCommunityMembersAndAdmins(
                    widget.community.id,
                    List.from(selectedMembers),
                    List.from(selectedAdmins),
                  );

                  setState(() {
                    widget.community.name = nameController.text;
                    widget.community.description = descriptionController.text;
                    widget.community.members = List.from(selectedMembers);
                    widget.community.admins = List.from(selectedAdmins);
                    if (newPhotoUrl != null) {
                      widget.community.photoUrl = newPhotoUrl;
                    }
                  });

                  Navigator.pop(context);
                  Navigator.pop(context, true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Topluluk başarıyla güncellendi')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Güncelleme sırasında hata oluştu: $e')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }

  void _showLeaveDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Topluluktan Ayrıl'),
        content: Text('${widget.community.name} topluluğundan ayrılmak istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _leaveCommunity();
            },
            child: const Text('Ayrıl'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.community.name),
        actions: [
          if (_currentUsername != null && 
              (widget.community.admins.contains(_currentUsername) || 
               _userAuthorityLevel == 2))
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _showEditDialog,
            ),
          if (_currentUsername != null && 
              widget.community.members.contains(_currentUsername))
            IconButton(
              icon: const Icon(Icons.exit_to_app),
              onPressed: () => _showLeaveDialog(),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_communityImageBytes != null)
              Center(
                child: CircleAvatar(
                  radius: 50,
                  backgroundImage: MemoryImage(_communityImageBytes!),
                ),
              ),
            const SizedBox(height: 16.0),

            // Topluluk açıklaması
            Text(
              widget.community.description,
              style: const TextStyle(
                fontSize: 16.0,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 16.0),

            // Üyeler
            const Text(
              'Üyeler',
              style: TextStyle(
                fontSize: 18.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8.0),
            for (var member in widget.community.members)
              ListTile(
                leading: const Icon(Icons.person),
                title: Text(member),
              ),
            const SizedBox(height: 16.0),

            // Adminler
            const Text(
              'Adminler',
              style: TextStyle(
                fontSize: 18.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8.0),
            for (var admin in widget.community.admins)
              ListTile(
                leading: const Icon(Icons.admin_panel_settings),
                title: Text(admin),
              ),
            const SizedBox(height: 16.0),

            // Etkinlikler
            const Text(
              'Etkinlikler',
              style: TextStyle(
                fontSize: 18.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8.0),
            if (_communityEvents.isEmpty)
              Center(
                child: Text(
                  'Henüz etkinlik bulunmuyor',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 16.0,
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _communityEvents.length,
                itemBuilder: (context, index) {
                  final event = _communityEvents[index];
                  final imageBytes = _eventImages[event.id!];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16.0),
                    child: ListTile(
                      leading: SizedBox(
                        width: 50,
                        height: 50,
                        child: imageBytes != null
                            ? Image.memory(
                                imageBytes,
                                fit: BoxFit.cover,
                              )
                            : event.imageUrl.isNotEmpty
                                ? Image.network(
                                    event.imageUrl,
                                    errorBuilder: (context, error, stackTrace) =>
                                        const Icon(Icons.event, size: 50),
                                    fit: BoxFit.cover,
                                  )
                                : const Icon(Icons.event, size: 50),
                      ),
                      title: Text(event.title),
                      subtitle: Text(_formatDateTime(event.dateTime)),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EventDetailsScreen(event: event),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
