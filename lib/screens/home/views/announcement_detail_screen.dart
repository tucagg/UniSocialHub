// lib/screens/home/views/announcement_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:gtu/models/announcement_model.dart';
import 'package:gtu/services/announcement_service.dart';

class AnnouncementDetailScreen extends StatefulWidget {
  final Announcement announcement;

  const AnnouncementDetailScreen({Key? key, required this.announcement}) : super(key: key);

  @override
  AnnouncementDetailScreenState createState() => AnnouncementDetailScreenState();
}

class AnnouncementDetailScreenState extends State<AnnouncementDetailScreen> {
  late Future<String> detailFuture;

  @override
  void initState() {
    super.initState();
    detailFuture = fetchAnnouncementDetail(widget.announcement.detailUrl);
  }

  Future<void> _openInBrowser() async {
    final uri = Uri.parse(widget.announcement.detailUrl);
    print(uri);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open URL')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const int maxLength = 500;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.announcement.title),
      ),
      body: FutureBuilder<String>(
        future: detailFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (snapshot.hasData) {
            final fullText = snapshot.data ?? '';
            final isLong = fullText.length > maxLength;
            final displayText = isLong ? '${fullText.substring(0, maxLength)}...' : fullText;

            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(displayText),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _openInBrowser,
                      child: const Text('Tarayıcıda Görüntüle'),
                    ),
                  ],
                ),
              ),
            );
          }
          return const SizedBox();
        },
      ),
    );
  }
}
