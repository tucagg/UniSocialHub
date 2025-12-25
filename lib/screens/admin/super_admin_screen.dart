import 'package:flutter/material.dart';
import 'base_admin_screen.dart';
import '../../../constants.dart';
import '../../../database/database_helper.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

class SuperAdminScreen extends BaseAdminScreen {
  const SuperAdminScreen({Key? key}) : super(key: key);

  @override
  _SuperAdminScreenState createState() => _SuperAdminScreenState();
}

class _SuperAdminScreenState extends BaseAdminScreenState<SuperAdminScreen> {
  List<String> _departments = [];

  @override
  void initState() {
    super.initState();
    _loadDepartments();
  }

  Future<void> _loadDepartments() async {
    try {
      String jsonString = await DefaultAssetBundle.of(context).loadString('lib/screens/auth/undergraduate_majors.json');
      final List<dynamic> jsonList = json.decode(jsonString);
      setState(() {
        _departments = jsonList.cast<String>();
      });
    } catch (e) {
      print('Bölümler yüklenirken hata: $e');
    }
  }

  @override
  Widget build(BuildContext context) => buildBaseScaffold();

  @override
  Widget buildUserCard(Map<String, dynamic> user) => buildSuperAdminUserCard(user);

  @override
  bool canEditUser(Map<String, dynamic> user) {
    return true; // Süper admin tüm kullanıcıları düzenleyebilir
  }

  @override
  int getRequiredAuthorityLevel() => SUPER_ADMIN;

  Widget buildSuperAdminUserCard(Map<String, dynamic> user) {
    List<Widget> actionButtons = [
      buildActionButton(
        icon: Icons.admin_panel_settings,
        label: 'Yetkileri Düzenle',
        onPressed: () => showEditUserDialog(user),
        color: Colors.blue,
      ),
      buildActionButton(
        icon: Icons.edit,
        label: 'Bilgileri Düzenle',
        onPressed: () => showEditUserInfoDialog(user),
        color: Colors.green,
      ),
      buildDisableButton(user),
    ];
    
    return buildBaseUserCard(user, actionButtons);
  }

  @override
  List<DropdownMenuItem<int>> getAuthorityItems() {
    return [
      DropdownMenuItem(value: USER, child: Text('Kullanıcı')),
      DropdownMenuItem(value: ADMIN, child: Text('Admin')),
      DropdownMenuItem(value: SUPER_ADMIN, child: Text('Süper Admin')),
    ];
  }

  @override
  Widget buildEditUserInfoDialog(Map<String, dynamic> user) {
    final firstNameController = TextEditingController(text: user['first_name']);
    final lastNameController = TextEditingController(text: user['last_name']);
    final departmentController = TextEditingController(text: user['department']);
    final entryYearController = TextEditingController(text: user['entry_year']?.toString());

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        width: 400,
        padding: EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: getAuthorityColor(user['authority_level'] ?? 0).withOpacity(0.1),
                    child: Text(
                      (user['username'] ?? '?')[0].toUpperCase(),
                      style: TextStyle(
                        color: getAuthorityColor(user['authority_level'] ?? 0),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kullanıcı Bilgilerini Düzenle',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          user['username'] ?? 'İsimsiz Kullanıcı',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24),
              _buildInputField(
                controller: firstNameController,
                label: 'Ad',
                icon: Icons.person_outline,
                textCapitalization: TextCapitalization.words,
              ),
              SizedBox(height: 16),
              _buildInputField(
                controller: lastNameController,
                label: 'Soyad',
                icon: Icons.person_outline,
                textCapitalization: TextCapitalization.words,
              ),
              SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: DropdownButtonFormField<String>(
                  value: user['department'],
                  decoration: InputDecoration(
                    labelText: 'Bölüm',
                    prefixIcon: Icon(Icons.school_outlined, color: purpleColor),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  isExpanded: true,
                  items: _departments.map((String department) {
                    return DropdownMenuItem<String>(
                      value: department,
                      child: Text(department, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      departmentController.text = newValue;
                    }
                  },
                ),
              ),
              SizedBox(height: 16),
              _buildInputField(
                controller: entryYearController,
                label: 'Giriş Yılı',
                icon: Icons.calendar_today_outlined,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
              ),
              SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'İptal',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 16,
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  SizedBox(
                    width: 120,
                    child: ElevatedButton(
                      onPressed: () async {
                        try {
                          await DatabaseHelper().updateUserInfo(
                            user['email'],
                            {
                              'first_name': firstNameController.text,
                              'last_name': lastNameController.text,
                              'department': departmentController.text,
                              'entry_year': entryYearController.text,
                            },
                          );
                          Navigator.pop(context);
                          loadUsers();
                          
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Kullanıcı bilgileri başarıyla güncellendi'),
                              backgroundColor: Colors.green,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              margin: EdgeInsets.all(10),
                            ),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Bir hata oluştu: $e'),
                              backgroundColor: Colors.red,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              margin: EdgeInsets.all(10),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: purpleColor,
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Kaydet',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: purpleColor),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        textInputAction: TextInputAction.next,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        textCapitalization: textCapitalization,
        scrollPadding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 16.0),
        enableInteractiveSelection: true,
        autocorrect: false,
        enableSuggestions: false,
      ),
    );
  }

  void showEditUserInfoDialog(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => buildEditUserInfoDialog(user),
    );
  }

  @override
  String getScreenTitle() => 'Süper Admin Paneli';

  @override
  List<AdminTab> getTabs() {
    return [
      AdminTab(
        title: 'Kullanıcı Yönetimi',
        icon: Icons.people,
        iconColor: purpleColor,
        textColor: purpleColor,
        content: Container(
          color: Colors.grey[100],
          child: buildUserList(),
        ),
      ),
      // Removed Rejected Events Tab
    ];
  }
}