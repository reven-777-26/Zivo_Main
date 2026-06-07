import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;

void pickImagePlatform(Function(String base64, String name) onSelected) {
  final uploadInput = html.FileUploadInputElement()..accept = 'image/*';
  uploadInput.click();
  uploadInput.onChange.listen((e) {
    final files = uploadInput.files;
    if (files != null && files.isNotEmpty) {
      final file = files[0];
      final reader = html.FileReader();
      reader.readAsDataUrl(file);
      reader.onLoadEnd.listen((e) {
        final String rawResult = reader.result as String;

        // Resize and compress image using HTML Canvas
        final img = html.ImageElement();
        img.src = rawResult;
        img.onLoad.listen((_) {
          const double maxDim = 600.0;
          double width = (img.width ?? 0).toDouble();
          double height = (img.height ?? 0).toDouble();

          if (width == 0 || height == 0) {
            // Fallback if size not detected
            final commaIndex = rawResult.indexOf(',');
            if (commaIndex != -1) {
              onSelected(rawResult.substring(commaIndex + 1), file.name);
            }
            return;
          }

          if (width > maxDim || height > maxDim) {
            if (width > height) {
              height = (height / width) * maxDim;
              width = maxDim;
            } else {
              width = (width / height) * maxDim;
              height = maxDim;
            }
          }

          final canvas = html.CanvasElement(
            width: width.round(),
            height: height.round(),
          );
          
          final ctx = canvas.context2D;
          ctx.drawImageScaled(img, 0, 0, width.round(), height.round());

          // Export as compressed JPEG (70% quality)
          final String compressedResult = canvas.toDataUrl('image/jpeg', 0.7);
          final commaIndex = compressedResult.indexOf(',');
          if (commaIndex != -1) {
            final base64 = compressedResult.substring(commaIndex + 1);
            onSelected(base64, file.name);
          }
        });
      });
    }
  });
}

Future<String> scanBarcodePlatform(String base64) async {
  try {
    // 1. Ensure ZXing is loaded
    if (!js.context.hasProperty('ZXing')) {
      final completer = Completer<void>();
      final script = html.ScriptElement()
        ..src = "https://unpkg.com/@zxing/library@0.19.1/umd/index.min.js"
        ..async = true;
      script.onLoad.listen((_) => completer.complete());
      script.onError.listen((e) => completer.completeError(e));
      html.document.head?.append(script);
      await completer.future;
    }

    // 2. Prepare callback
    final completer = Completer<String>();
    // ignore: undefined_function
    js.context['__zxingCallback'] = js.allowInterop((String text) {
      completer.complete(text);
    });

    // 3. Execute JS decode
    final String dataUrl = "data:image/jpeg;base64,$base64";
    js.context.callMethod('eval', ["""
      (async () => {
        try {
          const reader = new window.ZXing.BrowserMultiFormatReader();
          const result = await reader.decodeFromImageUrl("$dataUrl");
          window.__zxingCallback(result.text || "");
        } catch (e) {
          window.__zxingCallback("");
        }
      })();
    """]);

    return completer.future;
  } catch (e) {
    return "";
  }
}
