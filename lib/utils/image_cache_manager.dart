import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class ImageCacheManager {
  static Future<String> _getCacheDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${directory.path}/profile_cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create();
    }
    return cacheDir.path;
  }

  static String _generateCacheKey(String url) {
    return md5.convert(utf8.encode(url)).toString();
  }

  static Future<File> getCachedImageFile(String imageUrl) async {
    final cacheDir = await _getCacheDirectory();
    final cacheKey = _generateCacheKey(imageUrl);
    return File('$cacheDir/$cacheKey.jpg');
  }

  static Future<bool> hasValidCache(String imageUrl) async {
    final file = await getCachedImageFile(imageUrl);
    return file.exists();
  }

  static Future<void> cacheImage(String imageUrl, Uint8List imageBytes) async {
    final file = await getCachedImageFile(imageUrl);
    await file.writeAsBytes(imageBytes);
    print('Resim önbelleğe kaydedildi: $imageUrl');
  }

  static Future<Uint8List?> getCachedImage(String imageUrl) async {
    try {
      final file = await getCachedImageFile(imageUrl);
      if (await file.exists()) {
        print('Resim önbellekten yüklendi: $imageUrl');
        return await file.readAsBytes();
      }
      print('Resim önbellekte bulunamadı: $imageUrl');
    } catch (e) {
      print('Önbellekten resim okuma hatası: $e');
    }
    return null;
  }

  static Future<void> clearCache() async {
    try {
      final cacheDir = Directory('${(await getApplicationDocumentsDirectory()).path}/profile_cache');
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        print('Önbellek temizlendi');
      }
    } catch (e) {
      print('Önbellek temizleme hatası: $e');
    }
  }
}