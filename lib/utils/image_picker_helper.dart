import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../services/scanner/camera_barcode_scanner.dart';
import '../services/scanner/native_barcode_scanner.dart';
import 'web_barcode_scanner.dart';
import 'image_picker_stub.dart'
    if (dart.library.html) 'image_picker_web.dart'
    if (dart.library.io) 'image_picker_native.dart';

class BarcodeDebugInfo {
  final String? imagePath;
  final int? fileSize;
  final int? width;
  final int? height;
  final int detectedCount;
  final String? rawBarcodeValue;
  final String? exception;
  final String? zxingImageBase64;
  final String? mimeType;
  final DateTime timestamp;

  BarcodeDebugInfo({
    this.imagePath,
    this.fileSize,
    this.width,
    this.height,
    required this.detectedCount,
    this.rawBarcodeValue,
    this.exception,
    this.zxingImageBase64,
    this.mimeType,
  }) : timestamp = DateTime.now();
}

class ImagePickerHelper {
  static BarcodeDebugInfo? lastDebugInfo;

  static void pickImage(
    Function(String base64, String name, String? filePath) onSelected, {
    bool isBarcode = false,
    bool fromCamera = false,
  }) {
    pickImagePlatform(onSelected, isBarcode: isBarcode, fromCamera: fromCamera);
  }

  /// Decodes barcode from base64 string or file path.
  /// Uses Native ML Kit on Android/iOS, and falls back to pure-Dart ZXing.
  static Future<String> scanBarcode(String base64String, {String? filePath}) async {
    // 1. Try Native ML Kit first if we have a file path and are on mobile
    if (!kIsWeb && filePath != null && filePath.isNotEmpty) {
      try {
        final nativeResult = await NativeBarcodeScanner.scanImage(filePath);
        if (nativeResult != null && nativeResult.isNotEmpty) {
          debugPrint("ML Kit decoded barcode: $nativeResult");
          lastDebugInfo = BarcodeDebugInfo(
            imagePath: filePath,
            detectedCount: 1,
            rawBarcodeValue: nativeResult,
            mimeType: 'image/native',
          );
          return nativeResult;
        }
      } catch (e) {
        debugPrint("Native ML Kit scan failed, falling back: $e");
      }
    }

    // 1.5. Try Web Native BarcodeDetector first if we are on Web
    if (kIsWeb) {
      try {
        final webResult = await scanBarcodeWebPlatform(base64String);
        if (webResult != null && webResult.isNotEmpty) {
          debugPrint("Web BarcodeDetector decoded barcode: $webResult");
          lastDebugInfo = BarcodeDebugInfo(
            imagePath: filePath,
            detectedCount: 1,
            rawBarcodeValue: webResult,
            mimeType: 'image/web-native',
          );
          return webResult;
        }
      } catch (e) {
        debugPrint("Web BarcodeDetector scan failed, falling back: $e");
      }
    }

    // 2. Fallback to pure-Dart ZXing (for Web or if ML Kit fails)
    try {
      Uint8List bytes;
      
      // Decode base64 to bytes (handling data URL prefix if present)
      String cleanBase64 = base64String;
      final commaIndex = base64String.indexOf(',');
      if (commaIndex != -1) {
        cleanBase64 = base64String.substring(commaIndex + 1);
      }
      bytes = base64Decode(cleanBase64.replaceAll(RegExp(r'\s+'), ''));

      // Decode bytes using pure-Dart image library
      img.Image? decoded = img.decodeImage(bytes);
      if (decoded != null) {
        // Downscale image if too large to make ZXing barcode detection faster & more reliable
        if (decoded.width > 1024 || decoded.height > 1024) {
          decoded = img.copyResize(
            decoded,
            width: decoded.width > decoded.height ? 1024 : null,
            height: decoded.height >= decoded.width ? 1024 : null,
          );
        }
        final rgbaBytes = decoded.getBytes(order: img.ChannelOrder.rgba);
        final frame = ImageFrame(
          bytes: rgbaBytes,
          width: decoded.width,
          height: decoded.height,
          format: 'rgba8888',
          rotation: 0,
        );
        
        final result = await CameraBarcodeScanner.detectBarcode(frame);
        if (result != null && result.isNotEmpty) {
          lastDebugInfo = BarcodeDebugInfo(
            imagePath: filePath,
            fileSize: bytes.length,
            width: decoded.width,
            height: decoded.height,
            detectedCount: 1,
            rawBarcodeValue: result,
            mimeType: 'image/png',
          );
          return result;
        }
      }
    } catch (e) {
      debugPrint("Pure Dart image scan failed: $e");
    }
    
    lastDebugInfo = BarcodeDebugInfo(
      imagePath: filePath,
      fileSize: 0,
      width: 0,
      height: 0,
      detectedCount: 0,
      rawBarcodeValue: null,
      mimeType: 'image/png',
      exception: "Decoding failed",
    );
    return "";
  }

  /// Extracts text from an image using on-device ML Kit OCR on mobile platforms.
  /// Returns null on Web or if it fails.
  static Future<String?> performOCR(String base64String, {String? filePath}) async {
    if (kIsWeb) return null;

    if (filePath != null && filePath.isNotEmpty) {
      try {
        final inputImage = InputImage.fromFilePath(filePath);
        final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
        final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
        await textRecognizer.close();
        return recognizedText.text;
      } catch (e) {
        debugPrint("Native ML Kit OCR failed: $e");
      }
    }
    return null;
  }
}
