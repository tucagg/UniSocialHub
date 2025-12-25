// lib/screens/home/views/home_screen.dart
import 'package:flutter/material.dart';
import 'package:gtu/models/announcement_model.dart';
import 'package:gtu/services/announcement_service.dart';
import 'announcement_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  late Future<List<Announcement>> universityAnnouncements;

  @override
  void initState() {
    super.initState();
    // Ana duyuru listesi sayfası:
    universityAnnouncements = fetchAnnouncements('https://www.gtu.edu.tr/kategori/9/0/display.aspx');
  }

  void _onAnnouncementTap(Announcement announcement) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AnnouncementDetailScreen(announcement: announcement),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GTU Announcements'),
      ),
      body: FutureBuilder<List<Announcement>>(
        future: universityAnnouncements,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No Announcements Found'));
          } else {
            final announcements = snapshot.data!;
            return ListView.builder(
              itemCount: announcements.length,
              itemBuilder: (context, index) {
                final announcement = announcements[index];
                return ListTile(
                  title: Text(announcement.title),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () => _onAnnouncementTap(announcement),
                );
              },
            );
          }
        },
      ),
    );
  }
}
