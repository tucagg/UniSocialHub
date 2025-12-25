// lib/screens/community/views/add_community_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../events/models/event_structure.dart';
import '../models/community_structure.dart';
import '../../../database/database_helper.dart';
import '../../../database/community_helper.dart';

class AddCommunityScreen extends StatefulWidget {
  const AddCommunityScreen({super.key});

  @override
  _AddCommunityScreenState createState() => _AddCommunityScreenState();
}

class _AddCommunityScreenState extends State<AddCommunityScreen> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final CommunityHelper _communityHelper = CommunityHelper();
  
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  
  List<Map<String, dynamic>> _allUsers = [];
  Set<String> _selectedMembers = {};
  Set<String> _selectedAdmins = {};
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    _loadUsers(isAdmin: false);
  }

  Future<void> _loadUsers({bool isAdmin = false}) async {
    try {
      final allUsers = await _databaseHelper.getAllUsers();
      setState(() {
        if (isAdmin) {
          // Admin listesi için yetki seviyesi 1'e eşit ve büyük olanları filtrele
          _allUsers = allUsers.where((user) => 
            (user['authority_level'] ?? 0) >= 1
          ).toList();
        } else {
          // Normal üyeler için tüm kullanıcıları göster
          _allUsers = allUsers;
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kullanıcılar yüklenirken hata oluştu: $e')),
      );
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 80,
    );

    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  void _showUserSelectionDialog({bool isAdmin = false}) async {
    try {
      final allUsers = await _databaseHelper.getAllUsers();
      setState(() {
        if (isAdmin) {
          _allUsers = allUsers.where((user) => 
            (user['authority_level'] ?? 0) >= 1
          ).toList();
        } else {
          _allUsers = allUsers;
        }
      });

      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(isAdmin ? 'Admin Seç' : 'Üye Seç'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _allUsers.length,
                itemBuilder: (context, index) {
                  final user = _allUsers[index];
                  final username = user['username'] as String;
                  final isSelected = isAdmin 
                      ? _selectedAdmins.contains(username)
                      : _selectedMembers.contains(username);
                  
                  return CheckboxListTile(
                    title: Text(username),
                    subtitle: Text(user['email'] ?? ''),
                    value: isSelected,
                    onChanged: (bool? value) {
                      setState(() {
                        if (isAdmin) {
                          if (value == true) {
                            _selectedAdmins.add(username);
                          } else {
                            _selectedAdmins.remove(username);
                          }
                        } else {
                          if (value == true) {
                            _selectedMembers.add(username);
                          } else {
                            _selectedMembers.remove(username);
                          }
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
                  Navigator.pop(context);
                },
                child: const Text('Tamam'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kullanıcılar yüklenirken hata oluştu: $e')),
      );
    }
  }

  void _saveCommunity() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedImage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lütfen bir topluluk fotoğrafı seçin')),
        );
        return;
      }

      try {
        final newCommunity = Community(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: _nameController.text,
          description: _descriptionController.text,
          photoUrl: _selectedImage!.path,
          members: _selectedMembers.toList(),
          admins: _selectedAdmins.toList(),
          events: [],
        );

        await _communityHelper.createCommunity(newCommunity);
        Navigator.pop(context, newCommunity);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Topluluk başarıyla oluşturuldu')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Topluluk oluşturulurken hata oluştu: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yeni Topluluk Oluştur'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              if (_selectedImage != null)
                Image.file(
                  _selectedImage!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ElevatedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.photo),
                label: const Text('Fotoğraf Seç'),
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Topluluk Adı',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Lütfen topluluk adını girin';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Açıklama',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Lütfen açıklamayı girin';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),
              ListTile(
                title: const Text('Seçilen Üyeler'),
                subtitle: Text(_selectedMembers.isEmpty 
                    ? 'Henüz üye seçilmedi' 
                    : _selectedMembers.join(', ')),
                trailing: IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _showUserSelectionDialog(isAdmin: false),
                ),
              ),
              const SizedBox(height: 16.0),
              ListTile(
                title: const Text('Seçilen Adminler'),
                subtitle: Text(_selectedAdmins.isEmpty 
                    ? 'Henüz admin seçilmedi' 
                    : _selectedAdmins.join(', ')),
                trailing: IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _showUserSelectionDialog(isAdmin: true),
                ),
              ),
              const SizedBox(height: 24.0),
              ElevatedButton(
                onPressed: _saveCommunity,
                child: const Text('Kaydet'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}