import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

enum MediaType { image, video }

class CloudinaryService {
  static const String cloudName = 'dfgwg5acw'; 
  static const String uploadPreset = 'recipe_daily_upload'; 
  
  // API endpoints
  static const String imageUploadUrl = 
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload';
  static const String videoUploadUrl = 
      'https://api.cloudinary.com/v1_1/$cloudName/video/upload';

  /// Upload Image
  Future<String> uploadImage({
    required File imageFile,
    String folder = 'recipes/images',
    Function(double)? onProgress,
  }) async {
    return await _uploadMedia(
      file: imageFile,
      mediaType: MediaType.image,
      folder: folder,
      onProgress: onProgress,
    );
  }

  /// Upload Video
  Future<String> uploadVideo({
    required File videoFile,
    String folder = 'recipes/videos',
    Function(double)? onProgress,
  }) async {
    return await _uploadMedia(
      file: videoFile,
      mediaType: MediaType.video,
      folder: folder,
      onProgress: onProgress,
    );
  }

  /// Generic Upload Method
  Future<String> _uploadMedia({
    required File file,
    required MediaType mediaType,
    required String folder,
    Function(double)? onProgress,
  }) async {
    try {
      final url = mediaType == MediaType.image ? imageUploadUrl : videoUploadUrl;
      final mediaTypeStr = mediaType == MediaType.image ? 'image' : 'video';
      
      print('Uploading $mediaTypeStr to Cloudinary...');
      print('   File size: ${(file.lengthSync() / 1024 / 1024).toStringAsFixed(2)} MB');
      
      final request = http.MultipartRequest('POST', Uri.parse(url));
      
      // Read file bytes once
      final fileBytes = await file.readAsBytes();
      final fileLength = fileBytes.length;
      
      // Add file from bytes
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        fileBytes,
        filename: file.path.split('/').last,
      ));
      
      // Add parameters
      request.fields['upload_preset'] = uploadPreset;
      request.fields['folder'] = folder;
      
      // Generate unique public_id
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = file.path.split('/').last.split('.').first;
      request.fields['public_id'] = '${filename}_$timestamp';
      
      // Video-specific settings
      if (mediaType == MediaType.video) {
        request.fields['resource_type'] = 'video';
        request.fields['eager'] = 'sp_hd/mp4'; // Auto-convert to MP4
        request.fields['eager_async'] = 'true';
      }
      
      print('Sending request to Cloudinary...');
      
      // Send request
      final streamedResponse = await request.send();
      
      print('Response status: ${streamedResponse.statusCode}');
      
      // Convert response to bytes
      final responseBytes = await streamedResponse.stream.toBytes();
      final responseString = String.fromCharCodes(responseBytes);
      
      if (streamedResponse.statusCode == 200) {
        final jsonResponse = jsonDecode(responseString);
        final mediaUrl = jsonResponse['secure_url'] as String;
        
        print('$mediaTypeStr uploaded successfully');
        print('   URL: $mediaUrl');
        return mediaUrl;
      } else {
        print('Upload failed: $responseString');
        throw Exception('Failed to upload $mediaTypeStr: ${streamedResponse.statusCode} - $responseString');
      }
    } catch (e) {
      print('Upload error: $e');
      throw Exception('Failed to upload: $e');
    }
  }

  /// Upload Multiple Images
  Future<List<String>> uploadMultipleImages({
    required List<File> imageFiles,
    String folder = 'recipes/images',
    Function(int current, int total)? onProgress,
  }) async {
    final List<String> uploadedUrls = [];
    
    for (int i = 0; i < imageFiles.length; i++) {
      print('Uploading image ${i + 1}/${imageFiles.length}...');
      
      if (onProgress != null) {
        onProgress(i + 1, imageFiles.length);
      }
      
      final url = await uploadImage(
        imageFile: imageFiles[i],
        folder: folder,
      );
      uploadedUrls.add(url);
    }
    
    return uploadedUrls;
  }

  /// Get video thumbnail URL
  String getVideoThumbnail(String videoUrl) {
    return videoUrl.replaceAll('/video/upload/', '/video/upload/so_0/');
  }

  /// Get optimized image URL
  String getOptimizedImageUrl(
    String imageUrl, {
    int? width,
    int? height,
    String quality = 'auto',
    String format = 'auto',
  }) {
    // Insert transformations into URL
    final transformations = <String>[];
    
    if (quality != 'auto') transformations.add('q_$quality');
    if (format != 'auto') transformations.add('f_$format');
    if (width != null) transformations.add('w_$width');
    if (height != null) transformations.add('h_$height');
    
    if (transformations.isEmpty) {
      transformations.addAll(['q_auto', 'f_auto']);
    }
    
    final transformation = transformations.join(',');
    return imageUrl.replaceAll('/upload/', '/upload/$transformation/');
  }

  /// Delete media
  Future<bool> deleteMedia(String publicId) async {
    print('Delete requires API credentials');
    print('   Manage media at: https://cloudinary.com/console/media_library');
    print('   Public ID: $publicId');
    return false;
  }

  /// Validate file before upload
  static bool validateImage(File file) {
    final ext = file.path.split('.').last.toLowerCase();
    final allowedExts = ['jpg', 'jpeg', 'png', 'gif', 'webp'];
    
    if (!allowedExts.contains(ext)) {
      print('Invalid image format: $ext');
      return false;
    }
    
    final sizeMB = file.lengthSync() / 1024 / 1024;
    if (sizeMB > 10) {
      print('Image too large: ${sizeMB.toStringAsFixed(2)} MB (max 10MB)');
      return false;
    }
    
    return true;
  }

  static bool validateVideo(File file) {
    final ext = file.path.split('.').last.toLowerCase();
    final allowedExts = ['mp4', 'mov', 'avi', 'mkv', 'webm'];
    
    if (!allowedExts.contains(ext)) {
      print('Invalid video format: $ext');
      return false;
    }
    
    final sizeMB = file.lengthSync() / 1024 / 1024;
    if (sizeMB > 100) {
      print('Video too large: ${sizeMB.toStringAsFixed(2)} MB (max 100MB)');
      return false;
    }
    
    return true;
  }
}