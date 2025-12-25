import 'package:flutter/material.dart';
import '../../../constants.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../route/route_constants.dart';
import '../../../database/database_helper.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:image_cropper/image_cropper.dart';
import 'package:flutter/cupertino.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class SetUsernameScreen extends StatefulWidget {
  const SetUsernameScreen({Key? key}) : super(key: key);

  @override
  _SetUsernameScreenState createState() => _SetUsernameScreenState();
}

class _SetUsernameScreenState extends State<SetUsernameScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  bool _isLoading = false;
  XFile? _profileImage;
  DateTime? _selectedDate;
  List<String> _departments = [];
  String? _selectedDepartment;

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
        setState(() {
          _profileImage = XFile(croppedFile.path);
        });
      }
    }
  }

  Future<String?> _uploadImageToS3() async {
    if (_profileImage == null) return null;

    final file = File(_profileImage!.path);
    final fileName = '${_usernameController.text}_${DateTime.now().millisecondsSinceEpoch}.jpg';

    return await DatabaseHelper().uploadFileToS3(file, 'profile_images', fileName);
  }

  Future<void> _setUsername() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      try {
        bool isUsernameTaken = await DatabaseHelper().isUsernameTaken(_usernameController.text);
        if (isUsernameTaken) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Bu kullanıcı adı zaten kullanımda. Lütfen başka bir kullanıcı adı seçin.')),
          );
          return;
        }

        User? user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await user.updateDisplayName(_usernameController.text);
          String? imageUrl = await _uploadImageToS3();
          await DatabaseHelper().updateUserDetails(
            user.email!,
            _usernameController.text,
            _selectedDate!.year,
            _selectedDepartment!
          );
          
          if (imageUrl != null) {
            await DatabaseHelper().updateProfileImageUrl(user.email!, imageUrl);
          }

          Navigator.pushNamedAndRemoveUntil(
              context, entryPointScreenRoute, (route) => false);
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profil oluşturulurken bir hata oluştu. Lütfen tekrar deneyin.')),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectYear(BuildContext context) async {
    final DateTime? picked = await showDialog<DateTime>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            height: 300,
            child: YearPicker(
              firstDate: DateTime(1990),
              lastDate: DateTime.now(),
              selectedDate: _selectedDate ?? DateTime.now(),
              onChanged: (DateTime dateTime) {
                setState(() {
                  _selectedDate = dateTime;
                });
                Navigator.pop(context, dateTime);
              },
            ),
          ),
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadDepartments();
  }

  Future<void> _loadDepartments() async {
    final String response = await rootBundle.loadString('lib/screens/auth/undergraduate_majors.json');
    final List<dynamic> data = json.decode(response);
    setState(() {
      _departments = data.cast<String>();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Profilinizi Oluşturun'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(defaultPadding),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: 20),
                GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.grey[300],
                        child: _profileImage == null
                            ? Icon(Icons.camera_alt, size: 40, color: Colors.grey[600])
                            : ClipOval(
                                child: Image.file(
                                  File(_profileImage!.path),
                                  fit: BoxFit.cover,
                                  width: 120,
                                  height: 120,
                                ),
                              ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: purpleColor,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: Icon(Icons.camera_alt, color: Colors.white),
                          onPressed: _pickImage,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Profil Fotoğrafı Ekle',
                  style: TextStyle(color: purpleColor),
                ),
                SizedBox(height: 30),
                TextFormField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: 'Kullanıcı Adı',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Lütfen bir kullanıcı adı girin';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 20),
                GestureDetector(
                  onTap: () => _selectYear(context),
                  child: AbsorbPointer(
                    child: TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Giriş Yılı',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        prefixIcon: Icon(Icons.calendar_today),
                        suffixIcon: Icon(Icons.arrow_drop_down),
                      ),
                      controller: TextEditingController(
                        text: _selectedDate != null ? "${_selectedDate!.year}" : "",
                      ),
                      validator: (value) {
                        if (_selectedDate == null) {
                          return 'Lütfen giriş yılınızı seçin';
                        }
                        return null;
                      },
                    ),
                  ),
                ),
                SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  value: _selectedDepartment,
                  decoration: InputDecoration(
                    labelText: 'Bölüm',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    prefixIcon: Icon(Icons.school),
                  ),
                  items: _departments.map((String department) {
                    return DropdownMenuItem<String>(
                      value: department,
                      child: Container(
                        constraints: BoxConstraints(maxWidth: 250), // Genişliği sınırla
                        child: Text(
                          department,
                          overflow: TextOverflow.ellipsis, // Uzun metinleri kırp
                          style: TextStyle(fontSize: 14), // Yazı boyutunu küçült
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedDepartment = newValue;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Lütfen bölümünüzü seçin';
                    }
                    return null;
                  },
                  isExpanded: true, // Dropdown'ın genişliğini maksimuma çıkar
                  itemHeight: 50, // Her öğenin yüksekliğini ayarla
                  menuMaxHeight: 300, // Menünün maksimum yüksekliğini ayarla
                ),
                SizedBox(height: 30),
                ElevatedButton(
                  onPressed: _isLoading ? null : _setUsername,
                  child: _isLoading
                      ? CircularProgressIndicator(color: Colors.white)
                      : Text('Profili Oluştur'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: purpleColor,
                    padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                    textStyle: TextStyle(fontSize: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
