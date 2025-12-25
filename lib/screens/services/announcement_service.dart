import 'package:http/http.dart' as http;
import 'package:html/parser.dart';

Future<List<String>> fetchAnnouncements(String url) async {
  final response = await http.get(Uri.parse(url));
  if (response.statusCode == 200) {
    final document = parse(response.body);

    // "Duyurular" yazısını bul ve sonraki `li` öğelerini al
    final announcementTitle = document.querySelectorAll('li');
    final startIndex = announcementTitle.indexWhere((element) => element.text.contains("Duyurular"));

    // Duyurular yazısından sonraki öğeleri seç ve ilk 5 öğeyi al
    final elements = announcementTitle.sublist(startIndex + 1, startIndex + 6);
    return elements.map((e) => e.text.trim()).toList();
  } else {
    throw Exception('Duyuruları yükleyemedik');
  }
}