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

        final html.ImageElement img = html.ImageElement(src: rawResult);
        img.onLoad.first.then((_) {
          int width = img.width ?? 0;
          int height = img.height ?? 0;
          
          if (width == 0 || height == 0) {
            _deliverResult(rawResult, file.name, isBarcode, onSelected);
            uploadInput.remove();
            return;
          }

          final maxDim = 1024;
          if (width > maxDim || height > maxDim) {
            if (width > height) {
              height = (height * maxDim / width).round();
              width = maxDim;
            } else {
              width = (width * maxDim / height).round();
              height = maxDim;
            }
          }

          final canvas = html.CanvasElement(width: width, height: height);
          final ctx = canvas.context2D;
          ctx.drawImageScaled(img, 0, 0, width, height);

          // Convert to JPEG base64 with 80% quality
          final compressedResult = canvas.toDataUrl('image/jpeg', 0.8);
          _deliverResult(compressedResult, file.name, isBarcode, onSelected);
          uploadInput.remove();
        }).catchError((_) {
          _deliverResult(rawResult, file.name, isBarcode, onSelected);
          uploadInput.remove();
        });
      });
    } else {
      uploadInput.remove();
    }
  });
}

void _deliverResult(String dataUrl, String filename, bool isBarcode, Function(String base64, String name, String? filePath) onSelected) {
  if (isBarcode) {
    onSelected(dataUrl, filename, null);
  } else {
    final commaIndex = dataUrl.indexOf(',');
    if (commaIndex != -1) {
      onSelected(dataUrl.substring(commaIndex + 1), filename, null);
    } else {
      onSelected(dataUrl, filename, null);
    }
  }
}
