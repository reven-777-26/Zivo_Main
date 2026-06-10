import 'dart:async';
import 'dart:js' as js;

/// Scans a barcode from a data URL or HTTP image URL.
/// Uses native BarcodeDetector API first, then falls back to ZXing JS.
/// ZXing is pre-loaded via index.html so it is always available.
Future<String?> scanBarcodeWebImpl(String base64OrImageUrl) async {
  try {
    _injectJsScanner();

    // Each call gets a unique token so results from concurrent calls don't collide.
    final token = 'bc_${DateTime.now().millisecondsSinceEpoch}';
    js.context.callMethod('detectBarcodeFromSrcToken', [base64OrImageUrl, token]);

    // Poll up to 8 seconds (80 × 100ms). ZXing on a large image can take 2-5s.
    for (int i = 0; i < 80; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      final result = js.context['barcodeResult_$token']?.toString();
      if (result == null) continue; // still PENDING (key not set yet)
      if (result.isEmpty || result == 'NOT_FOUND' || result.startsWith('ERROR')) {
        break;
      }
      // Clear the result slot before returning
      js.context['barcodeResult_$token'] = null;
      return result;
    }
    // Clean up any leftover key
    js.context['barcodeResult_$token'] = null;
  } catch (e) {
    // Suppress scan errors silently
  }
  return null;
}

/// Always injects/re-injects the JS scanner to ensure it is fresh and correct.
void _injectJsScanner() {
  js.context.callMethod('eval', [
    r"""
    window.detectBarcodeFromSrcToken = async function(src, token) {
      // Mark as in-progress by NOT setting the key yet (Dart polls for key existence)

      // Load the image element
      const imgEl = new Image();
      imgEl.crossOrigin = 'anonymous';
      imgEl.src = src;
      await new Promise((resolve) => {
        imgEl.onload = resolve;
        imgEl.onerror = resolve;
        // Force resolve after 5s in case onload never fires for large blobs
        setTimeout(resolve, 5000);
      });

      if (!imgEl.complete || imgEl.naturalWidth === 0) {
        window['barcodeResult_' + token] = 'NOT_FOUND';
        return;
      }

      // ── Strategy 1: Chrome's native BarcodeDetector (fastest) ────────────
      if ('BarcodeDetector' in window) {
        try {
          const supported = await BarcodeDetector.getSupportedFormats();
          const wanted = ['ean_13', 'ean_8', 'code_128', 'code_39', 'upc_a', 'upc_e', 'qr_code'];
          const active = wanted.filter(f => supported.includes(f));
          if (active.length > 0) {
            const detector = new BarcodeDetector({ formats: active });
            const found = await detector.detect(imgEl);
            if (found && found.length > 0) {
              window['barcodeResult_' + token] = found[0].rawValue;
              return;
            }
          }
        } catch (e) {
          console.warn('[Zivofit] BarcodeDetector failed:', e);
        }
      }

      // ── Strategy 2: ZXing JS (pre-loaded in index.html) ─────────────────
      // Draw image to canvas so ZXing can read pixel data cross-origin safely
      try {
        const canvas = document.createElement('canvas');
        canvas.width  = imgEl.naturalWidth;
        canvas.height = imgEl.naturalHeight;
        const ctx = canvas.getContext('2d');
        ctx.drawImage(imgEl, 0, 0);

        // decodeFromCanvas is synchronous-ish and does NOT need a URL fetch
        if (window.ZXing) {
          const reader = new window.ZXing.BrowserMultiFormatReader();
          try {
            const result = reader.decodeFromCanvas(canvas);
            if (result && result.text) {
              window['barcodeResult_' + token] = result.text;
              return;
            }
          } catch (notFound) {
            // ZXing throws NotFoundException when barcode not found — that's expected
          }

          // Also try the full-image luminance source hints path with every hint
          try {
            const hints = new Map();
            hints.set(window.ZXing.DecodeHintType.TRY_HARDER, true);
            const readerHard = new window.ZXing.BrowserMultiFormatReader(hints);
            const resultHard = readerHard.decodeFromCanvas(canvas);
            if (resultHard && resultHard.text) {
              window['barcodeResult_' + token] = resultHard.text;
              return;
            }
          } catch (_) {}
        }
      } catch (e) {
        console.warn('[Zivofit] ZXing canvas decode failed:', e);
      }

      window['barcodeResult_' + token] = 'NOT_FOUND';
    };
    """
  ]);
}
