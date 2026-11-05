import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// ImgBB Image Upload Service
/// Used for storing farmer photos, receipts, and other images
class ImgBBService {
  // ImgBB API key
  static const String _apiKey = '1d973cd74f9135eec200426332572234';
  static const String _uploadUrl = 'https://api.imgbb.com/1/upload';
  
  /// Upload image to ImgBB
  /// Returns the image URL if successful, null otherwise
  static Future<String?> uploadImage(File imageFile, {String? name}) async {
    try {
      // Read image as base64
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);
      
      // Prepare request
      final uri = Uri.parse(_uploadUrl);
      final request = http.MultipartRequest('POST', uri)
        ..fields['key'] = _apiKey
        ..fields['image'] = base64Image;
      
      if (name != null) {
        request.fields['name'] = name;
      }
      
      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['success'] == true) {
          // Return the URL
          return jsonResponse['data']['url'] as String;
        }
      }
      
      return null;
    } catch (e) {
      print('ImgBB upload error: $e');
      return null;
    }
  }
  
  /// Upload image with progress callback
  static Future<String?> uploadImageWithProgress(
    File imageFile, {
    String? name,
    Function(double)? onProgress,
  }) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);
      
      final uri = Uri.parse(_uploadUrl);
      final request = http.MultipartRequest('POST', uri)
        ..fields['key'] = _apiKey
        ..fields['image'] = base64Image;
      
      if (name != null) {
        request.fields['name'] = name;
      }
      
      // Track upload progress
      int bytesSent = 0;
      request.onProgress = (sent, total) {
        bytesSent = sent;
        if (onProgress != null && total > 0) {
          onProgress(sent / total);
        }
      };
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['success'] == true) {
          return jsonResponse['data']['url'] as String;
        }
      }
      
      return null;
    } catch (e) {
      print('ImgBB upload error: $e');
      return null;
    }
  }
  
  /// Validate image file before upload
  static bool validateImage(File imageFile) {
    // Check file exists
    if (!imageFile.existsSync()) {
      return false;
    }
    
    // Check file size (ImgBB free tier: 32MB limit)
    final fileSizeInMB = imageFile.lengthSync() / (1024 * 1024);
    if (fileSizeInMB > 32) {
      return false;
    }
    
    // Check file extension
    final extension = imageFile.path.split('.').last.toLowerCase();
    final validExtensions = ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'];
    if (!validExtensions.contains(extension)) {
      return false;
    }
    
    return true;
  }
}

extension on http.MultipartRequest {
  set onProgress(Function(int sent, int total) callback) {
    // This would require a custom implementation
    // For now, this is a placeholder for progress tracking
  }
}
