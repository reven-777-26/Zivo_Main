import 'dart:io';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';

class NativeBarcodeScanner {
  static final BarcodeScanner _barcodeScanner = BarcodeScanner();

  static Future<String?> scanImage(String filePath) async {
    if (kIsWeb || !Platform.isAndroid && !Platform.isIOS) {
      return null;
    }

    try {
      final inputImage = InputImage.fromFilePath(filePath);
      final List<Barcode> barcodes = await _barcodeScanner.processImage(inputImage);

      if (barcodes.isNotEmpty) {
        return barcodes.first.rawValue;
      }
    } catch (e) {
      debugPrint('ML Kit Scan Error: $e');
    }
    return null;
  }

  static Future<String?> scanBytes(Uint8List bytes, int width, int height, InputImageFormat format, int rotation) async {
     if (kIsWeb || !Platform.isAndroid && !Platform.isIOS) {
      return null;
    }

    try {
      final inputImage = InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(width.toDouble(), height.toDouble()),
          rotation: _getRotation(rotation),
          format: format,
          bytesPerRow: width, // Simplification for Y plane
        ),
      );

      final List<Barcode> barcodes = await _barcodeScanner.processImage(inputImage);
      if (barcodes.isNotEmpty) {
        return barcodes.first.rawValue;
      }
    } catch (e) {
      debugPrint('ML Kit Stream Scan Error: $e');
    }
    return null;
  }

  static Future<String?> scanCameraImage(CameraImage image, CameraDescription camera) async {
    if (kIsWeb || !Platform.isAndroid && !Platform.isIOS) {
      return null;
    }

    try {
      final Uint8List bytes;
      final InputImageFormat format;
      final int bytesPerRow;

      if (Platform.isAndroid) {
        bytes = _yuv420ToNv21(image);
        format = InputImageFormat.nv21;
        bytesPerRow = image.width;
      } else {
        // iOS
        bytes = image.planes[0].bytes;
        format = InputImageFormat.bgra8888;
        bytesPerRow = image.planes[0].bytesPerRow;
      }

      final rotation = _getRotation(camera.sensorOrientation);

      final inputImage = InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: bytesPerRow,
        ),
      );

      final List<Barcode> barcodes = await _barcodeScanner.processImage(inputImage);
      if (barcodes.isNotEmpty) {
        return barcodes.first.rawValue;
      }
    } catch (e) {
      debugPrint('ML Kit Stream Scan Error: $e');
    }
    return null;
  }

  static Uint8List _yuv420ToNv21(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final yBytes = yPlane.bytes;
    final uBytes = uPlane.bytes;
    final vBytes = vPlane.bytes;

    final nv21 = Uint8List(width * height + (width * height ~/ 2));

    // Copy Y plane row by row to discard padding
    int ySourceOffset = 0;
    int yDestOffset = 0;
    for (int h = 0; h < height; h++) {
      nv21.setRange(yDestOffset, yDestOffset + width, yBytes, ySourceOffset);
      ySourceOffset += yPlane.bytesPerRow;
      yDestOffset += width;
    }

    // Copy V and U planes (interleaved, chroma is half width and half height)
    final chromaWidth = width ~/ 2;
    final chromaHeight = height ~/ 2;
    int chromaDestOffset = width * height;

    for (int h = 0; h < chromaHeight; h++) {
      final int uRowStart = h * uPlane.bytesPerRow;
      final int vRowStart = h * vPlane.bytesPerRow;
      for (int w = 0; w < chromaWidth; w++) {
        final int uPixelOffset = uRowStart + w * (uPlane.bytesPerPixel ?? 1);
        final int vPixelOffset = vRowStart + w * (vPlane.bytesPerPixel ?? 1);

        if (vPixelOffset < vBytes.length) {
          nv21[chromaDestOffset++] = vBytes[vPixelOffset];
        }
        if (uPixelOffset < uBytes.length) {
          nv21[chromaDestOffset++] = uBytes[uPixelOffset];
        }
      }
    }

    return nv21;
  }

  static InputImageRotation _getRotation(int rotation) {
    switch (rotation) {
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  static void dispose() {
    _barcodeScanner.close();
  }
}
