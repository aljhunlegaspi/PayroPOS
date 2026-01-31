import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../core/config/cloudinary_config.dart';

class ImageUploadResult {
  final bool success;
  final String? url;
  final String? publicId;
  final String? error;

  ImageUploadResult({
    required this.success,
    this.url,
    this.publicId,
    this.error,
  });
}

class ImageUploadService {
  /// Upload an image to Cloudinary
  /// [file] - The image file to upload
  /// [folder] - The folder to upload to (e.g., 'payropos/products')
  Future<ImageUploadResult> uploadImage(File file, {String? folder}) async {
    debugPrint('📤 Starting image upload...');
    debugPrint('   File path: ${file.path}');
    debugPrint('   File exists: ${file.existsSync()}');
    debugPrint('   File size: ${file.existsSync() ? file.lengthSync() : 0} bytes');
    debugPrint('   Upload URL: ${CloudinaryConfig.uploadUrl}');
    debugPrint('   Upload preset: ${CloudinaryConfig.uploadPreset}');
    debugPrint('   Folder: $folder');

    try {
      final uri = Uri.parse(CloudinaryConfig.uploadUrl);
      final request = http.MultipartRequest('POST', uri);

      // Add the file
      debugPrint('📤 Adding file to request...');
      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      // Add upload preset (for unsigned uploads)
      request.fields['upload_preset'] = CloudinaryConfig.uploadPreset;

      // Add folder if specified
      if (folder != null) {
        request.fields['folder'] = folder;
      }

      // Send the request
      debugPrint('📤 Sending request to Cloudinary...');
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('📤 Response status code: ${response.statusCode}');
      debugPrint('📤 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('✅ Upload successful!');
        debugPrint('   URL: ${data['secure_url']}');
        debugPrint('   Public ID: ${data['public_id']}');
        return ImageUploadResult(
          success: true,
          url: data['secure_url'],
          publicId: data['public_id'],
        );
      } else {
        final error = json.decode(response.body);
        final errorMsg = error['error']?['message'] ?? 'Upload failed with status ${response.statusCode}';
        debugPrint('❌ Upload failed: $errorMsg');
        return ImageUploadResult(
          success: false,
          error: errorMsg,
        );
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Upload exception: $e');
      debugPrint('   Stack trace: $stackTrace');
      return ImageUploadResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Upload product image
  Future<ImageUploadResult> uploadProductImage(File file) async {
    return uploadImage(file, folder: CloudinaryConfig.productImagesFolder);
  }

  /// Upload store logo
  Future<ImageUploadResult> uploadStoreLogo(File file) async {
    return uploadImage(file, folder: CloudinaryConfig.storeLogosFolder);
  }

  /// Upload user avatar
  Future<ImageUploadResult> uploadUserAvatar(File file) async {
    return uploadImage(file, folder: CloudinaryConfig.userAvatarsFolder);
  }

  /// Get optimized image URL with transformations
  /// [url] - The original Cloudinary URL
  /// [width] - Desired width
  /// [height] - Desired height
  /// [crop] - Crop mode (fill, fit, scale, etc.)
  String getOptimizedUrl(
    String url, {
    int? width,
    int? height,
    String crop = 'fill',
  }) {
    if (!url.contains('cloudinary.com')) return url;

    final parts = url.split('/upload/');
    if (parts.length != 2) return url;

    final transformations = <String>[];
    if (width != null) transformations.add('w_$width');
    if (height != null) transformations.add('h_$height');
    transformations.add('c_$crop');
    transformations.add('q_auto');
    transformations.add('f_auto');

    return '${parts[0]}/upload/${transformations.join(',')}/${parts[1]}';
  }

  /// Get thumbnail URL
  String getThumbnailUrl(String url, {int size = 150}) {
    return getOptimizedUrl(url, width: size, height: size, crop: 'fill');
  }
}
