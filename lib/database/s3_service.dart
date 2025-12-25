import 'package:aws_s3_api/s3-2006-03-01.dart';
import 'dart:io';
import 'dart:typed_data';

class S3Service {
  static final S3Service _instance = S3Service._internal();
  factory S3Service() => _instance;
  S3Service._internal();

  static const String _accessKey = 'EXAMPLE';
  static const String _secretKey = 'YOUR_SECRET_KEY';
  static const String _region = 'eu-north-1';
  static const String _bucket = 'tidibado-kampus';

  late final S3 _s3;

  String get bucket => _bucket;
  String get region => _region;

  String getS3Url(String folderPath, String fileName) {
    return 'https://$_bucket.s3.$_region.amazonaws.com/$folderPath/$fileName';
  }

  Future<void> init() async {
    _s3 = S3(
      region: _region,
      credentials: AwsClientCredentials(
        accessKey: _accessKey,
        secretKey: _secretKey,
      ),
    );
  }

  Future<String?> uploadFile(File file, String folderPath, String fileName, {String contentType = 'image/jpeg'}) async {
    try {
      final bytes = await file.readAsBytes();
      await _s3.putObject(
        bucket: _bucket,
        key: '$folderPath/$fileName',
        body: bytes,
        contentLength: bytes.length,
        contentType: contentType,
      );
      
      final url = getS3Url(folderPath, fileName);
      print('Upload successful. URL: $url');
      return url;
    } catch (e) {
      print('Upload failed: $e');
      return null;
    }
  }

  Future<void> deleteObject(String folderPath, String fileName) async {
    try {
      await _s3.deleteObject(
        bucket: _bucket,
        key: '$folderPath/$fileName',
      );
    } catch (e) {
      print('S3 dosya silme hatası: $e');
      throw e;
    }
  }

  Future<void> renameObject(String folderPath, String oldFileName, String newFileName) async {
    try {
      await _s3.copyObject(
        bucket: _bucket,
        key: '$folderPath/$newFileName',
        copySource: '/$_bucket/$folderPath/$oldFileName',
      );

      await deleteObject(folderPath, oldFileName);
    } catch (e) {
      print('S3 dosya yeniden adlandırma hatası: $e');
      throw e;
    }
  }

  Future<Uint8List?> getFile(String folderPath, String fileName) async {
    try {
      final response = await _s3.getObject(
        bucket: _bucket,
        key: '$folderPath/$fileName',
      );

      if (response.body != null) {
        return response.body;
      }
      print('Failed to get file: Data is null');
      return null;
    } catch (e) {
      print('Error getting file from S3: $e');
      return null;
    }
  }
}