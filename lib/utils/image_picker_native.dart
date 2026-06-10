import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

void pickImagePlatform(Function(String base64, String name, String? filePath) onSelected, {bool isBarcode = false, bool fromCamera = false}) async {
  try {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );
    if (pickedFile != null) {
      final file = File(pickedFile.path);
      final bytes = await file.readAsBytes();
      final base64String = base64Encode(bytes);
      
      if (isBarcode) {
        // Pass the base64 content with appropriate data URL prefix to preserve format
        final extension = pickedFile.path.split('.').last.toLowerCase();
        final mimeType = (extension == 'png') ? 'image/png' : 'image/jpeg';
        onSelected("data:$mimeType;base64,$base64String", pickedFile.name, pickedFile.path);
      } else {
        // Pass standard raw base64 string for general AI analysis
        onSelected(base64String, pickedFile.name, pickedFile.path);
      }
    }
  } catch (e) {
    // Fail silently
  }
}
