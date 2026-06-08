import 'dart:html' as html;

void pickImagePlatform(Function(String base64, String name, String? filePath) onSelected, {bool isBarcode = false, bool fromCamera = false}) {
  final uploadInput = html.FileUploadInputElement()
    ..accept = 'image/*'
    ..style.display = 'none';
  if (fromCamera) {
    uploadInput.setAttribute('capture', 'environment');
  }
  
  // Appending to the body is required for modern browsers to accept the click event
  html.document.body?.append(uploadInput);
  uploadInput.click();
  
  uploadInput.onChange.listen((e) {
    final files = uploadInput.files;
    if (files != null && files.isNotEmpty) {
      final file = files[0];
      final reader = html.FileReader();
      reader.readAsDataUrl(file);
      reader.onLoadEnd.listen((e) {
        final String rawResult = reader.result as String;

        if (isBarcode) {
          // Pass the complete rawResult (including data URL prefix)
          onSelected(rawResult, file.name, null);
        } else {
          // Pass standard raw base64 string for general AI analysis
          final commaIndex = rawResult.indexOf(',');
          if (commaIndex != -1) {
            onSelected(rawResult.substring(commaIndex + 1), file.name, null);
          } else {
            onSelected(rawResult, file.name, null);
          }
        }
        uploadInput.remove(); // Clean up from DOM
      });
    } else {
      uploadInput.remove(); // Clean up from DOM if cancelled
    }
  });
}
