import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../constants.dart';
import '../../../database/database_helper.dart';
import 'package:gtu/route/route_constants.dart';

abstract class BaseAdminScreen extends StatefulWidget {
  const BaseAdminScreen({Key? key}) : super(key: key);
}

abstract class BaseAdminScreenState<T extends BaseAdminScreen> extends State<T> with SingleTickerProviderStateMixin {
  @protected
  int authorityLevel = 0;
  @protected
  List<Map<String, dynamic>> users = [];
  @protected
  bool isLoading = true;
  late TabController _tabController;

  @protected
  Future<void> loadAuthorityLevel() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      var userData = await DatabaseHelper().getUserData(user.email!);
      setState(() {
        authorityLevel = userData['authority_level'] ?? 0;
      });
    }
  }

  @protected
  Future<void> loadUsers() async {
    try {
      var allUsers = await DatabaseHelper().getAllUsers();
      setState(() {
        users = allUsers;
        isLoading = false;
      });
    } catch (e) {
      print('Kullanıcılar yüklenirken hata: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: getTabs().length, vsync: this);
    loadAuthorityLevel();
    loadUsers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<AdminTab> getTabs() {
    return [
      AdminTab(
        title: 'Kullanıcı Yönetimi',
        icon: Icons.people,
        content: buildUserList(),
      ),
    ];
  }

  @protected
  TabController get tabController => _tabController;

  @protected
  Widget buildBaseScaffold() {
    if (authorityLevel < getRequiredAuthorityLevel()) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 80, color: Colors.grey[400]),
              SizedBox(height: 24),
              Text(
                'Bu sayfaya erişim yetkiniz yok.',
                style: TextStyle(fontSize: 20, color: Colors.grey[700]),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        iconTheme: IconThemeData(
          color: Colors.white,
        ),
        title: Text(
          getScreenTitle(),
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 22,
            color: Colors.white,
          ),
        ),
        elevation: 0,
        backgroundColor: purpleColor,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: loadUsers,
            tooltip: 'Listeyi Yenile',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: purpleColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  offset: Offset(0, 2),
                  blurRadius: 4,
                )
              ],
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              indicatorPadding: EdgeInsets.symmetric(horizontal: 20),
              labelStyle: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
              unselectedLabelStyle: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
              tabs: getTabs().map((tab) => Container(
                height: 56,
                child: Tab(
                  icon: Icon(
                    tab.icon,
                    color: Colors.white,
                    size: 28,
                  ),
                  child: Text(
                    tab.title,
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              )).toList(),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: getTabs().map((tab) => tab.content).toList(),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => buildBaseScaffold();

  String getScreenTitle() => 'Admin Paneli';

  @protected
  Widget buildUserList() {
    return isLoading
        ? Center(child: CircularProgressIndicator())
        : Container(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.people_outline, color: purpleColor, size: 28),
                        SizedBox(width: 12),
                        Text(
                          'Toplam Kullanıcı: ${users.length}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = users[index];
                      return buildUserCard(user);
                    },
                  ),
                ),
              ],
            ),
          );
  }

  @protected
  Widget buildUserCard(Map<String, dynamic> user);

  bool canEditUser(Map<String, dynamic> user);
  int getRequiredAuthorityLevel();
  
  String getAuthorityText(int level) {
    switch (level) {
      case SUPER_ADMIN:
        return 'Süper Admin';
      case ADMIN:
        return 'Admin';
      default:
        return 'Kullanıcı';
    }
  }

  Color getAuthorityColor(int level) {
    switch (level) {
      case SUPER_ADMIN:
        return Colors.red;
      case ADMIN:
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  Future<void> showEditUserDialog(Map<String, dynamic> user) async {
    if (user['email'] == FirebaseAuth.instance.currentUser?.email) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kendi yetki seviyenizi değiştiremezsiniz.')),
      );
      return;
    }

    int userAuthorityLevel = user['authority_level'] ?? 0;
    if (!canEditUser(user)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bu kullanıcının yetkisini değiştiremezsiniz.')),
      );
      return;
    }

    int newAuthorityLevel = user['authority_level'] ?? 0;
    await showDialog(
      context: context,
      builder: (context) => buildEditUserDialog(user, newAuthorityLevel),
    );
    
    // Dialog kapandıktan sonra kullanıcı listesini yenile
    await loadUsers();
  }

  @protected
  Widget buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildBaseUserCard(
    Map<String, dynamic> user,
    List<Widget> actionButtons,
  ) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: getAuthorityColor(user['authority_level'] ?? 0).withOpacity(0.1),
          child: Text(
            (user['username'] ?? '?')[0].toUpperCase(),
            style: TextStyle(
              color: getAuthorityColor(user['authority_level'] ?? 0),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          user['username'] ?? 'İsimsiz Kullanıcı',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Text(
              user['email'] ?? '',
              style: TextStyle(color: Colors.black54),
            ),
            SizedBox(height: 6),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: getAuthorityColor(user['authority_level'] ?? 0).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                getAuthorityText(user['authority_level'] ?? 0),
                style: TextStyle(
                  fontSize: 12,
                  color: getAuthorityColor(user['authority_level'] ?? 0),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(15),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                buildInfoRow('Ad Soyad', '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'),
                buildInfoRow('Bölüm', user['department'] ?? 'Belirtilmemiş'),
                buildInfoRow('Giriş Yılı', user['entry_year']?.toString() ?? 'Belirtilmemiş'),
                SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: actionButtons,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> toggleUserDisableStatus(Map<String, dynamic> user) async {
    try {
      final isDisabled = user['disabled'] ?? false;
      if (isDisabled) {
        await enableUser(user['email']);
      } else {
        await disableUser(user['email']);
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isDisabled 
              ? '${user['username']} kullanıcısının hesabı aktifleştirildi.' 
              : '${user['username']} kullanıcısının hesabı devre dışı bırakıldı.'
          ),
          backgroundColor: isDisabled ? Colors.green : Colors.red,
        ),
      );
      
      await loadUsers();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bir hata oluştu: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget buildDisableButton(Map<String, dynamic> user) {
    final isDisabled = user['disabled'] ?? false;
    
    return buildActionButton(
      icon: isDisabled ? Icons.lock_open : Icons.block,
      label: isDisabled ? 'Hesabı Aktifleştir' : 'Hesabı Devre Dışı Bırak',
      onPressed: () => toggleUserDisableStatus(user),
      color: isDisabled ? Colors.orange : Colors.red,
    );
  }

  Future<void> disableUser(String email) async {
    try {
      // Kullanıcının yetkisini kontrol et
      final userData = await DatabaseHelper().getUserData(email);
      final userAuthorityLevel = userData['authority_level'] ?? 0;
      final currentUser = FirebaseAuth.instance.currentUser;
      
      // Eğer admin kendisini veya daha yüksek yetkili birini banlamaya çalışıyorsa engelle
      if (currentUser?.email == email || userAuthorityLevel >= getRequiredAuthorityLevel()) {
        throw Exception('Bu kullanıcıyı devre dışı bırakamazsınız.');
      }

      // Kullanıcıyı devre dışı bırak
      await DatabaseHelper().updateUserDisabledStatus(email, true);
      
      // Kullanıcının aktif oturumunu sonlandır
      final users = await FirebaseAuth.instance.fetchSignInMethodsForEmail(email);
      if (users.isNotEmpty) {
        await FirebaseAuth.instance.signOut();
      }
      
      await loadUsers(); // Kullanıcı listesini yenile
    } catch (e) {
      print('Kullanıcı disable edilirken hata: $e');
      throw e;
    }
  }

  Future<void> enableUser(String email) async {
    try {
      await DatabaseHelper().updateUserDisabledStatus(email, false);
    } catch (e) {
      print('Kullanıcı enable edilirken hata: $e');
      throw e;
    }
  }

  @protected
  Widget buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  @protected
  Widget buildEditUserDialog(Map<String, dynamic> user, int initialAuthorityLevel) {
    return StatefulBuilder(
      builder: (context, setState) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: SingleChildScrollView(
          child: Container(
            width: 400,
            padding: EdgeInsets.all(24),
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
                            'Kullanıcı Yetkisini Düzenle',
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
                Text(
                  'Yetki Seviyesi',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: DropdownButtonFormField<int>(
                    value: initialAuthorityLevel,
                    items: getAuthorityItems(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => initialAuthorityLevel = value);
                      }
                    },
                    decoration: InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      border: InputBorder.none,
                    ),
                    icon: Icon(Icons.keyboard_arrow_down, color: purpleColor),
                    dropdownColor: Colors.white,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
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
                          await DatabaseHelper().updateUserAuthority(
                            user['email'],
                            initialAuthorityLevel,
                          );
                          Navigator.pop(context);
                          loadUsers();
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
      ),
    );
  }

  @protected
  List<DropdownMenuItem<int>> getAuthorityItems() {
    return [
      DropdownMenuItem(value: USER, child: Text('Kullanıcı')),
    ];
  }
}

class AdminTab {
  final String title;
  final IconData icon;
  final Widget content;
  final Color? iconColor;
  final Color? textColor;

  AdminTab({
    required this.title,
    required this.icon,
    required this.content,
    this.iconColor,
    this.textColor,
  });
}
