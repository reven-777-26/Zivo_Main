import 'package:flutter/foundation.dart';
import 'package:zxing_lib/zxing.dart';
import 'package:zxing_lib/common.dart';

class ImageFrame {
  final Uint8List bytes;          // Raw image data (RGBA or YUV)
  final int width;
  final int height;
  final String format;              // 'yuv420', 'rgba8888', etc.
  final int rotation;               // 0, 90, 180, 270

  ImageFrame({
    required this.bytes,
    required this.width,
    required this.height,
    required this.format,
    required this.rotation,
  });
}

class CameraBarcodeScanner {
  /// Decodes barcode from a universal ImageFrame using pure Dart zxing_lib.
  static Future<String?> detectBarcode(ImageFrame frame) async {
    try {
      LuminanceSource source;

      if (frame.format == 'yuv420') {
        // On Mobile/Android, yBytes is raw luminance data
        source = PlanarYUVLuminanceSource(
          frame.bytes,
          frame.width,
          frame.height,
        );
      } else {
        // On Web, convert RGBA bytes to grayscale luminance
        final Uint8List luminances = Uint8List(frame.width * frame.height);
        final int size = frame.width * frame.height;
        final rgba = frame.bytes;
        
        for (int i = 0; i < size; i++) {
          final r = rgba[i * 4];
          final g = rgba[i * 4 + 1];
          final b = rgba[i * 4 + 2];
          luminances[i] = ((r + (g << 1) + b) ~/ 4);
        }
        source = RGBLuminanceSource.orig(frame.width, frame.height, luminances);
      }

      // Crop to center focus area where user aligns barcode
      if (source.isCropSupported) {
        final int cropWidth = (source.width * 0.65).round();
        final int cropHeight = (source.height * 0.45).round();
        final int cropLeft = (source.width - cropWidth) ~/ 2;
        final int cropTop = (source.height - cropHeight) ~/ 2;
        source = source.crop(cropLeft, cropTop, cropWidth, cropHeight);
      }

      // Configure decoding hints for improved accuracy and speed
      final hint = DecodeHint(
        tryHarder: true,
        possibleFormats: [
          BarcodeFormat.ean13,
          BarcodeFormat.ean8,
          BarcodeFormat.code128,
          BarcodeFormat.code39,
          BarcodeFormat.qrCode,
        ],
      );

      // Automatically try HybridBinarizer first (good for 2D/QR codes)
      BinaryBitmap bitmap = BinaryBitmap(HybridBinarizer(source));
      final reader = MultiFormatReader();
      
      try {
        final result = reader.decode(bitmap, hint);
        if (result.text.isNotEmpty) {
          debugPrint("ZXing (Pure Dart) decoded barcode: ${result.text}");
          return result.text;
        }
      } catch (_) {
        // Try fallback to GlobalHistogramBinarizer (good for 1D/EAN barcodes)
        try {
          bitmap = BinaryBitmap(GlobalHistogramBinarizer(source));
          final result = reader.decode(bitmap, hint);
          if (result.text.isNotEmpty) {
            debugPrint("ZXing (Pure Dart) decoded barcode (fallback): ${result.text}");
            return result.text;
          }
        } catch (_) {
          // No barcode found
        }
      }
    } catch (e) {
      debugPrint("ZXing Pure Dart Scanning Exception: $e");
    }
    return null;
  }
}
