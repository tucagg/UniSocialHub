import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:gtu/constants.dart';
import 'package:gtu/route/screen_export.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../database/database_helper.dart';
import '../../../components/network_image_with_loader.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:image_cropper/image_cropper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../../../utils/image_cache_manager.dart';


class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _profileImageUrl;
  String? _username;
  Uint8List? _profileImageBytes;
  bool _isLoading = false;
  int _authorityLevel = 0;
  int? _entryYear;
  String? _department;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      var userData = await DatabaseHelper().getUserData(user.email!);
      
      setState(() {
        _username = userData['username'];
        _authorityLevel = userData['authority_level'] ?? 0;
      });
      
      if (userData['profile_image_url'] != null) {
        String imageUrl = userData['profile_image_url'];
        
        // Önce önbellekten resmi kontrol et
        Uint8List? cachedImage = await ImageCacheManager.getCachedImage(imageUrl);
        
        if (cachedImage != null) {
          print('Profil resmi önbellekten yüklendi');
          setState(() {
            _profileImageUrl = imageUrl;
            _username = userData['username'];
            _profileImageBytes = cachedImage;
          });
        } else {
          print('Profil resmi S3\'ten yükleniyor');
          // Önbellekte yoksa S3'ten indir ve önbelleğe al
          Uint8List? imageBytes = await DatabaseHelper().getImageFromS3(imageUrl);
          if (imageBytes != null) {
            await ImageCacheManager.cacheImage(imageUrl, imageBytes);
            setState(() {
              _profileImageUrl = imageUrl;
              _username = userData['username'];
              _profileImageBytes = imageBytes;
            });
          }
        }
      } else {
        setState(() {
          _username = userData['username'];
        });
      }
    }
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final TextEditingController passwordController = TextEditingController();
    bool confirm = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Hesabı Sil'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Hesabınızı silmek istediğinizden emin misiniz? Bu işlem geri alınamaz.'),
              SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Şifrenizi Girin',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: Text('İptal'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: Text('Sil'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirm) {
      try {
        User? user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          // 1. Kullanıcının kimliğini yeniden doğrula
          AuthCredential credential = EmailAuthProvider.credential(
            email: user.email!,
            password: passwordController.text,
          );
          
          try {
            await user.reauthenticateWithCredential(credential);
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Şifre yanlış. Lütfen tekrar deneyin.')),
            );
            return;
          }

          // 2. Firebase'den hesabı sil
          await user.delete();
          
          // 3. Veritabanından kullanıcı bilgilerini ve profil resmini sil
          await DatabaseHelper().deleteUserAndProfileImage(user.email!);
          
          // 4. SharedPreferences'ı temizle
          final prefs = await SharedPreferences.getInstance();
          await prefs.clear();
          
          // 5. Login ekranına yönlendir
          Navigator.of(context).pushNamedAndRemoveUntil(
            logInScreenRoute, 
            (Route<dynamic> route) => false
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hesap silinirken bir hata oluştu: $e')),
        );
      } finally {
        passwordController.dispose();
      }
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: image.path,
        aspectRatio: CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Resmi Düzenle',
            toolbarColor: purpleColor,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'Resmi Düzenle',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
          ),
        ],
      );
      if (croppedFile != null) {
        _updateProfileImage(File(croppedFile.path));
      }
    }
  }

  Future<void> _updateProfileImage(File imageFile) async {
    setState(() {
      _isLoading = true;
    });

    String? newImageUrl;
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        var userData = await DatabaseHelper().getUserData(user.email!);
        String username = userData['username'] ?? 'user';
        
        String fileName = '${username}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        newImageUrl = await DatabaseHelper().uploadFileToS3(imageFile, 'profile_images', fileName);

        if (newImageUrl != null) {
          await DatabaseHelper().updateProfileImageUrl(user.email!, newImageUrl);

          if (_profileImageUrl != null) {
            final oldFileName = Uri.parse(_profileImageUrl!).pathSegments.last;
            await DatabaseHelper().deleteS3Object('profile_images', oldFileName);
            final oldFile = await ImageCacheManager.getCachedImageFile(_profileImageUrl!);
            if (await oldFile.exists()) {
              await oldFile.delete();
            }
          }

          final imageBytes = imageFile.readAsBytesSync();
          await ImageCacheManager.cacheImage(newImageUrl, imageBytes);

          setState(() {
            _profileImageUrl = newImageUrl;
            _profileImageBytes = imageBytes;
            _username = username;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Profil resmi başarıyla güncellendi.')),
          );
        }
      }
    } catch (e) {
      if (newImageUrl != null) {
        final fileName = Uri.parse(newImageUrl).pathSegments.last;
        await DatabaseHelper().deleteS3Object('profile_images', fileName);
        final newFile = await ImageCacheManager.getCachedImageFile(newImageUrl);
        if (await newFile.exists()) {
          await newFile.delete();
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profil resmi güncellenirken bir hata oluştu: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            floating: false,
            pinned: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          purpleColor,
                          Color(0xFF8E24AA),
                          Color(0xFF6A1B9A),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 70,
                    left: 0,
                    right: 0,
                    child: Column(
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 4),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 20,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: _pickImage,
                                    child: _profileImageBytes != null
                                        ? Image.memory(
                                            _profileImageBytes!,
                                            fit: BoxFit.cover,
                                          )
                                        : Container(
                                            color: Colors.grey[200],
                                            child: Icon(
                                              Icons.person,
                                              size: 80,
                                              color: Colors.grey[400],
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              right: 5,
                              bottom: 5,
                              child: Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: purpleColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: Icon(Icons.edit, size: 20, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        if (_username != null)
                          Text(
                            _username!,
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  color: Colors.black26,
                                  blurRadius: 2,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                children: [
                  _buildGlassCard(
                    'Hesap Bilgileri',
                    Icons.person_outline,
                    () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => AccountInfoScreen(
                          deleteAccount: () => _deleteAccount(context),
                        ),
                      ),
                    ),
                  ),
                  if (_authorityLevel >= SUPER_ADMIN)
                    _buildGlassCard(
                      'Süper Admin Paneli',
                      Icons.admin_panel_settings,
                      () => Navigator.pushNamed(context, superAdminScreenRoute),
                    )
                  else if (_authorityLevel >= ADMIN)
                    _buildGlassCard(
                      'Admin Paneli',
                      Icons.admin_panel_settings,
                      () => Navigator.pushNamed(context, adminScreenRoute),
                    ),
                  _buildGlassCard(
                    'Çıkış Yap',
                    Icons.logout,
                    () async {
                      await FirebaseAuth.instance.signOut();
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.clear();
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        logInScreenRoute,
                        (route) => false,
                      );
                    },
                    color: errorColor,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _buildGlassCard(String title, IconData icon, VoidCallback onTap, {Color? color}) {
  return Padding(
    padding: EdgeInsets.only(bottom: 16),
    child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: (color ?? purpleColor).withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (color ?? purpleColor).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(icon, color: color ?? purpleColor, size: 26),
                ),
                SizedBox(width: 20),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: color ?? Colors.black87,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 18,
                  color: (color ?? Colors.black54).withOpacity(0.7),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class AccountInfoScreen extends StatefulWidget {
  final VoidCallback deleteAccount;

  const AccountInfoScreen({Key? key, required this.deleteAccount}) : super(key: key);

  @override
  _AccountInfoScreenState createState() => _AccountInfoScreenState();
}

class _AccountInfoScreenState extends State<AccountInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _usernameController = TextEditingController();
  bool _isLoading = false;
  String? _currentUsername;
  String? _currentProfileImageUrl;
  int? _entryYear;
  String? _department;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      var userData = await DatabaseHelper().getUserData(user.email!);
      setState(() {
        _firstNameController.text = userData['first_name'] ?? '';
        _lastNameController.text = userData['last_name'] ?? '';
        _usernameController.text = userData['username'] ?? '';
        _currentUsername = userData['username'];
        _currentProfileImageUrl = userData['profile_image_url'];
        _entryYear = userData['entry_year'];
        _department = userData['department'];
      });
    }
  }

  Future<void> _updateUserInfo() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      try {
        User? user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await DatabaseHelper().updateUserNames(
            user.email!,
            _firstNameController.text,
            _lastNameController.text,
          );

          if (_usernameController.text != _currentUsername) {
            // Kullanıcı adı değiştirilmek isteniyorsa, önce kullanılabilir olup olmadığını kontrol et
            bool isUsernameTaken = await DatabaseHelper().isUsernameTaken(_usernameController.text);
            if (isUsernameTaken) {
              throw Exception('Bu kullanıcı adı zaten kullanımda. Lütfen başka bir kullanıcı adı seçin.');
            }

            await DatabaseHelper().updateUsernameAndProfileImage(
              user.email!,
              _usernameController.text,
              _currentProfileImageUrl,
            );
            await user.updateDisplayName(_usernameController.text);
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Bilgileriniz başarıyla güncellendi.')),
          );
          _loadUserData();
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bilgiler güncellenirken bir hata oluştu: $e')),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Hesap Bilgileri'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _usernameController,
                decoration: InputDecoration(labelText: 'Kullanıcı Adı'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Lütfen kullanıcı adınızı girin';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _firstNameController,
                decoration: InputDecoration(labelText: 'Ad'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Lütfen adınızı girin';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _lastNameController,
                decoration: InputDecoration(labelText: 'Soyad'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Lütfen soyadınızı girin';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Giriş Yılı',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                enabled: false,
                controller: TextEditingController(text: _entryYear?.toString() ?? 'Bilgi yok'),
              ),
              SizedBox(height: 16),
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Bölüm',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                enabled: false,
                controller: TextEditingController(text: _department ?? 'Bilgi yok'),
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _updateUserInfo,
                child: _isLoading
                    ? CircularProgressIndicator()
                    : Text('Bilgileri Güncelle'),
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: widget.deleteAccount,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: Text('Hesabı Sil'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

