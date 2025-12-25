import 'package:flutter/material.dart';
import 'base_admin_screen.dart';
import '../../../constants.dart';
import '../../../database/database_helper.dart';

class AdminScreen extends BaseAdminScreen {
  const AdminScreen({Key? key}) : super(key: key);

  @override
  _AdminScreenState createState() => _AdminScreenState();
}

class _AdminScreenState extends BaseAdminScreenState<AdminScreen> {
  @override
  String getScreenTitle() => 'Admin Paneli';

  @override
  List<AdminTab> getTabs() {
    return [
      AdminTab(
        title: 'Kullanıcı Yönetimi',
        icon: Icons.people,
        content: Container(
          color: Colors.grey[100],
          child: buildUserList(),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) => buildBaseScaffold();

  @override
  Widget buildUserCard(Map<String, dynamic> user) => buildAdminUserCard(user);
  @override
  bool canEditUser(Map<String, dynamic> user) {
    int userAuthorityLevel = user['authority_level'] ?? 0;
    return authorityLevel > userAuthorityLevel;
  }

  @override
  int getRequiredAuthorityLevel() => ADMIN;

  Widget buildAdminUserCard(Map<String, dynamic> user) {
    List<Widget> actionButtons = [];
    if (canEditUser(user)) {
      actionButtons.addAll([
        buildActionButton(
          icon: Icons.admin_panel_settings,
          label: 'Yetkileri Düzenle',
          onPressed: () => showEditUserDialog(user),
          color: Colors.blue,
        ),
        buildDisableButton(user),
      ]);
    }
    return buildBaseUserCard(user, actionButtons);
  }

  @override
  List<DropdownMenuItem<int>> getAuthorityItems() {
    return [
      DropdownMenuItem(value: USER, child: Text('Kullanıcı')),
      DropdownMenuItem(value: ADMIN, child: Text('Admin')),
    ];
  }
}

