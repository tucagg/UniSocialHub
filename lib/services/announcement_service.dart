// lib/services/announcement_service.dart
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:gtu/models/announcement_model.dart';

Future<List<Announcement>> fetchAnnouncements(String url) async {
  final response = await http.get(Uri.parse(url));
  if (response.statusCode == 200) {
    final document = parser.parse(response.body);

    // Duyuruların listelendiği seçici:
    // Güncel HTML'de duyurular hala `ul.flex.flex-col.space-y-3.list-disc.px-5 > li` altında
    final listItems = document.querySelectorAll('ul.flex.flex-col.space-y-3.list-disc.px-5 > li');
    final announcements = <Announcement>[];

    for (var li in listItems) {
      final linkElement = li.querySelector('a');
      if (linkElement != null) {
        final title = linkElement.text.trim();
        final detailHref = linkElement.attributes['href'] ?? '';
        // Tam URL oluşturma
        final detailUrl = Uri.parse('https://www.gtu.edu.tr').resolveUri(Uri.parse(detailHref)).toString();
        announcements.add(Announcement(title: title, detailUrl: detailUrl));
      }
    }

    return announcements;
  } else {
    throw Exception('Failed to load announcements');
  }
}

Future<String> fetchAnnouncementDetail(String detailUrl) async {
  final response = await http.get(Uri.parse(detailUrl));
  if (response.statusCode == 200) {
    final document = parser.parse(response.body);

    // Detay içeriği 'div.rich-text-content' içinde
    final contentDiv = document.querySelector('div.rich-text-content');
    if (contentDiv != null) {
      final textContent = contentDiv.text.trim();
      return textContent;
    }
    return '';
  } else {
    throw Exception('Failed to load announcement detail');
  }
}
