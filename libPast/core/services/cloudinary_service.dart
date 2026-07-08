import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class CloudinaryService {
  static String get cloudName => dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '';
  static String get uploadPreset => dotenv.env['CLOUDINARY_UPLOAD_PRESET'] ?? '';

  // Legacy method removed (was using dart:io File which breaks web compilation).
  // Use uploadImageBytes() instead for all platforms.

  static Future<String> uploadImageBytes(List<int> bytes, String filename) async {
    if (cloudName.isEmpty ||
        cloudName == "your_cloud_name" ||
        uploadPreset.isEmpty ||
        uploadPreset == "your_unsigned_preset" ||
        uploadPreset == "your_unsigned_upload_preset_here") {
      final mockImages = [
        'https://images.unsplash.com/photo-1608958415712-42171457497d?q=80&w=600&auto=format&fit=crop',
        'https://images.unsplash.com/photo-1542856391-010fb87dcfed?q=80&w=600&auto=format&fit=crop',
        'https://images.unsplash.com/photo-1600100397608-f010e423b971?q=80&w=600&auto=format&fit=crop',
        'https://images.unsplash.com/photo-1590050752117-238cb0fb12b1?q=80&w=600&auto=format&fit=crop',
      ];
      final hash = filename.hashCode % mockImages.length;
      return mockImages[hash];
    }

    try {
      final url = Uri.parse("https://api.cloudinary.com/v1_1/$cloudName/image/upload");
      final request = http.MultipartRequest("POST", url)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));

      final response = await request.send();
      if (response.statusCode == 200) {
        final responseData = await response.stream.toBytes();
        final responseString = String.fromCharCodes(responseData);
        final jsonMap = jsonDecode(responseString);
        return jsonMap['secure_url'] ?? '';
      } else {
        throw Exception('Cloudinary upload failed: ${response.statusCode}');
      }
    } catch (e) {
      return 'https://images.unsplash.com/photo-1608958415712-42171457497d?q=80&w=600&auto=format&fit=crop';
    }
  }
}
