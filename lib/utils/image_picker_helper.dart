import 'image_picker_stub.dart'
    if (dart.library.html) 'image_picker_web.dart'
    if (dart.library.io) 'image_picker_native.dart';

class ImagePickerHelper {
  static void pickImage(Function(String base64, String name) onSelected) {
    pickImagePlatform(onSelected);
  }

  static Future<String> scanBarcode(String base64) {
    return scanBarcodePlatform(base64);
  }
}
