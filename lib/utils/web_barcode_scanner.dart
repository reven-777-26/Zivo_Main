import 'web_barcode_scanner_stub.dart'
    if (dart.library.html) 'web_barcode_scanner_web.dart';

Future<String?> scanBarcodeWebPlatform(String base64OrImageUrl) {
  return scanBarcodeWebImpl(base64OrImageUrl);
}
