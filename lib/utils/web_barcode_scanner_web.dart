import 'dart:async';
import 'dart:js' as js;

Future<String?> scanBarcodeWebImpl(String base64OrImageUrl) async {
  try {
    _ensureJsScannerInitialized();

    js.context.callMethod('detectBarcodeFromSrc', [base64OrImageUrl]);
    
    // Poll for the result up to 2 seconds (20 iterations * 100ms)
    for (int i = 0; i < 20; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      final result = js.context['lastBarcodeResult']?.toString();
      if (result != 'PENDING') {
        if (result != null && result.isNotEmpty && !result.startsWith('ERROR') && result != 'NOT_FOUND') {
          return result;
        }
        break; 
      }
    }
  } catch (e) {
    // Suppress scan errors
  }
  return null;
}

void _ensureJsScannerInitialized() {
  if (js.context.hasProperty('detectBarcodeFromSrc')) return;
  
  js.context.callMethod('eval', [
    """
    window.detectBarcodeFromSrc = async function(src) {
      window.lastBarcodeResult = 'PENDING';
      if (!('BarcodeDetector' in window)) {
        window.lastBarcodeResult = 'ERROR_UNSUPPORTED';
        return;
      }
      
      try {
        const formats = ['ean_13', 'ean_8', 'code_128', 'code_39', 'upc_a', 'upc_e', 'qr_code'];
        const supported = await BarcodeDetector.getSupportedFormats();
        const activeFormats = formats.filter(f => supported.includes(f));
        
        const detector = new BarcodeDetector({ formats: activeFormats });
        
        // Load the image
        const img = new Image();
        img.src = src;
        await new Promise((resolve) => {
          img.onload = resolve;
          img.onerror = resolve;
        });
        
        if (!img.complete || img.naturalWidth === 0) {
          window.lastBarcodeResult = 'NOT_FOUND';
          return;
        }
        
        const barcodes = await detector.detect(img);
        if (barcodes && barcodes.length > 0) {
          window.lastBarcodeResult = barcodes[0].rawValue;
          return;
        }
      } catch (err) {
        console.error('Error during BarcodeDetector.detect:', err);
      }
      window.lastBarcodeResult = 'NOT_FOUND';
    };
    """
  ]);
}
