import 'dart:convert';
import 'dart:ui' as ui;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import '../../core/theme.dart';
import '../../services/ai_backend_service.dart';
import '../../services/state_providers.dart';
import '../../utils/image_picker_helper.dart';
import '../../services/scanner/camera_barcode_scanner.dart';
import '../../services/scanner/native_barcode_scanner.dart';

class StandardFood {
  String foodName;
  int calories;
  int protein;
  int carbs;
  int fat;

  StandardFood({
    required this.foodName,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  Map<String, dynamic> toJson() => {
        'foodName': foodName,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
      };
}

class FoodLoggerDialog extends ConsumerStatefulWidget {
  const FoodLoggerDialog({super.key});

  @override
  ConsumerState<FoodLoggerDialog> createState() => _FoodLoggerDialogState();
}

class _FoodLoggerDialogState extends ConsumerState<FoodLoggerDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Global flow states
  bool _isLoading = false;
  String _loadingText = "Analyzing...";
  String? _errorMessage;
  StandardFood? _selectedFood;
  bool _showReview = false;
  String _selectedMealKey = 'breakfast_cal';

  // Barcode flow controllers
  final TextEditingController _barcodeController = TextEditingController();
  final List<Map<String, String>> _commonBarcodes = [
    {'name': 'Coca-Cola (330ml)', 'code': '5449000000996'},
  ];

  // Camera state fields
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  bool _isProcessingFrame = false;
  bool _isInitializing = false;
  Timer? _webFrameTimer;

  // Photo flow states
  String? _selectedImageBase64;

  // Voice flow states
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechAvailable = false;
  bool _isListening = false;
  String _voiceTranscript = "";
  final List<String> _sampleVoiceInputs = [
    "I ate 2 eggs and a banana",
    "1 bowl of oatmeal with milk and berries",
    "Grilled chicken salad with olive oil",
  ];

  // Text flow controllers
  final TextEditingController _textDescriptionController =
      TextEditingController();
  final List<String> _sampleTextInputs = [
    "2 scrambled eggs, one piece of toast, and half an avocado",
    "A glass of whole milk and a chocolate chip cookie",
    "150g grilled salmon with steamed broccoli and brown rice",
  ];

  // Review flow controllers
  late TextEditingController _reviewNameController;
  late TextEditingController _reviewCalController;
  late TextEditingController _reviewProteinController;
  late TextEditingController _reviewCarbsController;
  late TextEditingController _reviewFatController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _initSpeech();
    _initializeCamera();

    // Auto-select meal category based on time of day
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 11) {
      _selectedMealKey = 'breakfast_cal';
    } else if (hour >= 11 && hour < 16) {
      _selectedMealKey = 'lunch_cal';
    } else if (hour >= 16 && hour < 21) {
      _selectedMealKey = 'dinner_cal';
    } else {
      _selectedMealKey = 'snacks_cal';
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    _barcodeController.dispose();
    _textDescriptionController.dispose();
    _disposeCamera();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    if (_isInitializing) return;
    _isInitializing = true;
    try {
      await _disposeCamera();
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        final backCamera = _cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.back,
          orElse: () => _cameras.first,
        );

        _cameraController = CameraController(
          backCamera,
          ResolutionPreset.medium,
          enableAudio: false,
          imageFormatGroup: kIsWeb ? ImageFormatGroup.jpeg : ImageFormatGroup.yuv420,
        );

        await _cameraController!.initialize();
        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
            _errorMessage = null;
          });
          _startBarcodeScanningLoop();
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = "No camera found. Please upload an image instead.";
          });
        }
      }
    } catch (e) {
      debugPrint("Dialog camera initialization failed: $e");
      if (mounted) {
        setState(() {
          _errorMessage = "Camera access blocked or not supported on HTTP connection. Please upload an image instead.";
        });
      }
    } finally {
      _isInitializing = false;
    }
  }

  void _startBarcodeScanningLoop() {
    if (_cameraController == null || !_isCameraInitialized) return;

    if (kIsWeb) {
      _webFrameTimer = Timer.periodic(const Duration(milliseconds: 600), (timer) async {
        if (_isLoading || _isProcessingFrame || !mounted || _tabController.index != 0 || _showReview || _cameraController == null || !_isCameraInitialized || !_cameraController!.value.isInitialized) return;
        _isProcessingFrame = true;
        try {
          final XFile file = await _cameraController!.takePicture();
          if (!mounted || _cameraController == null || !_isCameraInitialized) {
            _isProcessingFrame = false;
            return;
          }
          final bytes = await file.readAsBytes();
          
          // Use native browser decoding (non-blocking) instead of pure-Dart img.decodeImage!
          // We downscale to 600px targetWidth to drastically reduce the RGBA byte buffer size & CPU usage.
          final ui.Codec codec = await ui.instantiateImageCodec(bytes, targetWidth: 600);
          final ui.FrameInfo frameInfo = await codec.getNextFrame();
          final ui.Image nativeImage = frameInfo.image;
          
          final byteData = await nativeImage.toByteData(format: ui.ImageByteFormat.rawRgba);
          if (byteData != null && mounted) {
            final rgbaBytes = byteData.buffer.asUint8List();
            final frame = ImageFrame(
              bytes: rgbaBytes,
              width: nativeImage.width,
              height: nativeImage.height,
              format: 'rgba8888',
              rotation: 0,
            );
            final barcode = await CameraBarcodeScanner.detectBarcode(frame);
            if (barcode != null && barcode.isNotEmpty && mounted) {
              _isProcessingFrame = true;
              await _runBarcodeScan(barcode);
              _isProcessingFrame = false;
            }
          }
        } catch (e) {
          if (_cameraController != null && _isCameraInitialized) {
            debugPrint("Web dialog barcode scan frame error: $e");
          }
        } finally {
          _isProcessingFrame = false;
        }
      });
    } else {
      _cameraController!.startImageStream((CameraImage image) async {
        if (_isLoading || _isProcessingFrame || !mounted || _tabController.index != 0 || _showReview) return;
        _isProcessingFrame = true;
        try {
          final barcode = await NativeBarcodeScanner.scanCameraImage(image, _cameraController!.description);
          if (barcode != null && barcode.isNotEmpty && mounted) {
            _isProcessingFrame = true;
            await _runBarcodeScan(barcode);
            _isProcessingFrame = false;
          }
        } catch (e) {
          debugPrint("Mobile dialog barcode scan frame error: $e");
        } finally {
          _isProcessingFrame = false;
        }
      });
    }
  }

  Future<void> _disposeCamera() async {
    _webFrameTimer?.cancel();
    _webFrameTimer = null;
    if (_cameraController != null) {
      if (_cameraController!.value.isStreamingImages) {
        try {
          await _cameraController!.stopImageStream();
        } catch (_) {}
      }
      try {
        await _cameraController!.dispose();
      } catch (_) {}
      _cameraController = null;
    }
    _isCameraInitialized = false;
  }

  void _handleTabSelection() {
    if (_tabController.index == 0) {
      if (_cameraController == null) {
        _initializeCamera();
      }
    } else {
      _disposeCamera();
    }
  }

  Future<void> _initSpeech() async {
    try {
      final available = await _speech.initialize(
        onStatus: (val) {
          if (val == 'done' || val == 'notListening') {
            setState(() => _isListening = false);
          }
        },
        onError: (val) {
          debugPrint("Speech recognition error: $val");
          setState(() {
            _isListening = false;
            _speechAvailable = false;
          });
        },
      );
      setState(() => _speechAvailable = available);
    } catch (e) {
      debugPrint("Speech initialization exception: $e");
      setState(() => _speechAvailable = false);
    }
  }

  void _startListening() async {
    if (_speechAvailable && !_isListening) {
      setState(() {
        _isListening = true;
        _voiceTranscript = "";
      });
      await _speech.listen(
        onResult: (val) {
          setState(() {
            _voiceTranscript = val.recognizedWords;
          });
        },
      );
    }
  }

  void _stopListening() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
    }
  }

  void _initializeReviewControllers() {
    if (_selectedFood != null) {
      _reviewNameController =
          TextEditingController(text: _selectedFood!.foodName);
      _reviewCalController =
          TextEditingController(text: _selectedFood!.calories.toString());
      _reviewProteinController =
          TextEditingController(text: _selectedFood!.protein.toString());
      _reviewCarbsController =
          TextEditingController(text: _selectedFood!.carbs.toString());
      _reviewFatController =
          TextEditingController(text: _selectedFood!.fat.toString());
    }
  }

  // Barcode API Integration
  Future<void> _runBarcodeScan(String barcode, {bool keepImage = false}) async {
    if (barcode.trim().isEmpty) return;
    setState(() {
      _isLoading = true;
      _loadingText = "Querying OpenFoodFacts API...";
      _errorMessage = null;
      if (!keepImage) {
        _selectedImageBase64 = null;
      }
    });

    try {
      final url = Uri.parse(
          'https://world.openfoodfacts.org/api/v0/product/$barcode.json');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['status'] == 1 && json['product'] != null) {
          final product = json['product'];
          final nutriments = product['nutriments'] ?? {};

          final name = product['product_name'] ?? 'Unknown Product';
          final cal = (nutriments['energy-kcal_100g'] ?? 0).round();
          final prot = (nutriments['proteins_100g'] ?? 0).round();
          final carb = (nutriments['carbohydrates_100g'] ?? 0).round();
          final fat = (nutriments['fat_100g'] ?? 0).round();

          final String? productImageUrl = product['image_url'] ??
              product['image_front_url'] ??
              product['image_small_url'];

          setState(() {
            _isLoading = false;
            _selectedFood = StandardFood(
              foodName: name,
              calories: cal,
              protein: prot,
              carbs: carb,
              fat: fat,
            );
            if (productImageUrl != null && productImageUrl.isNotEmpty) {
              _selectedImageBase64 = productImageUrl;
            } else {
              _selectedImageBase64 = null;
            }
            _initializeReviewControllers();
            _showReview = true;
          });
        } else {
          setState(() {
            _isLoading = false;
            _errorMessage = "Product Not Found";
          });
        }
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = "Product Not Found";
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Product Not Found";
      });
    }
  }

  // Local Barcode Image Extraction
  Future<void> _runBarcodeImageScan(String base64Content, String? imageName, {String? filePath}) async {
    setState(() {
      _isLoading = true;
      _loadingText = "Reading barcode from photo locally...";
      _errorMessage = null;
      _selectedImageBase64 = base64Content;
    });

    try {
      String? extracted;
      // 1. Try to extract from filename first (very useful fallback for test codes)
      if (imageName != null && imageName.isNotEmpty) {
        final RegExp barcodeRegex = RegExp(r'\b\d{8,14}\b');
        final match = barcodeRegex.firstMatch(imageName);
        if (match != null) {
          final code = match.group(0)!;
          // Ignore obvious millisecond timestamps or date patterns
          final bool isTimestamp = code.length == 13 &&
              (code.startsWith('15') || code.startsWith('16') || code.startsWith('17') || code.startsWith('18') || code.startsWith('19'));
          final bool isDate = code.length == 8 && (code.startsWith('202') || code.startsWith('203'));
          if (!isTimestamp && !isDate) {
            extracted = code;
          }
        }
      }

      // 2. If filename has no barcode, scan the image
      if (extracted == null || extracted.isEmpty) {
        final String barcode = await ImagePickerHelper.scanBarcode(base64Content, filePath: filePath);
        final trimmedBarcode = barcode.trim();
        if (trimmedBarcode.startsWith('ERROR:')) {
          debugPrint("Local barcode scan failed: $trimmedBarcode");
        } else if (trimmedBarcode.isNotEmpty) {
          final RegExp digitsRegex = RegExp(r'\d{8,14}');
          final match = digitsRegex.firstMatch(trimmedBarcode);
          if (match != null) {
            extracted = match.group(0);
          } else {
            extracted = trimmedBarcode;
          }
        }
      }

      if (extracted == null || extracted.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              "Could not read any barcode in this photo. Try another image.";
        });
      } else {
        // Automatically run OpenFoodFacts lookup on the extracted barcode digits!
        await _runBarcodeScan(extracted, keepImage: true);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Barcode extraction failed: ${e.toString()}";
      });
    }
  }

  Future<void> _runAssetBarcodeScan() async {
    setState(() {
      _isLoading = true;
      _loadingText = "Loading test barcode from assets...";
      _errorMessage = null;
    });
    try {
      final ByteData data = await rootBundle.load('assets/test_barcode.png');
      final List<int> bytes = data.buffer.asUint8List();
      final base64Content = base64Encode(bytes);
      // We explicitly pass the base64 content with a data URI format prefix for web
      final fullBase64 = "data:image/png;base64,$base64Content";
      await _runBarcodeImageScan(fullBase64, 'test_barcode.png');
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Failed to load test barcode asset: ${e.toString()}";
      });
    }
  }


  // Gemini API Integration via Cloud Function
  Future<void> _runGeminiAnalysis(String type, String content) async {
    setState(() {
      _isLoading = true;
      _loadingText = "Analyzing meal with Gemini 2.5 Flash...";
      _errorMessage = null;
      if (type != 'image') {
        _selectedImageBase64 = null;
      }
    });

    try {
      final result = await AIBackendService.analyzeMeal(
        type: type,
        content: content,
      );

      if (result.containsKey('error')) {
        throw Exception(result['error']);
      }

      setState(() {
        _isLoading = false;
        _selectedFood = StandardFood(
          foodName: result['foodName'] ?? 'Unknown Meal',
          calories: (result['calories'] ?? 0).toInt(),
          protein: (result['protein'] ?? 0).toInt(),
          carbs: (result['carbs'] ?? 0).toInt(),
          fat: (result['fat'] ?? 0).toInt(),
        );
        _initializeReviewControllers();
        _showReview = true;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "AI Analysis failed: ${e.toString()}";
      });
    }
  }

  void _showBarcodeDebugDialog(BuildContext context) {
    final info = ImagePickerHelper.lastDebugInfo;
    if (info == null) return;

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Dialog(
          backgroundColor: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 450),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.obsidianBackground.withOpacity(0.95)
                      : Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark
                        ? AppTheme.glassBorder
                        : Colors.black.withOpacity(0.08),
                    width: 1.5,
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Barcode Scanner Debug',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                              color: Colors.white,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pop(ctx),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.04),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                color: AppTheme.textSecondary,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildDebugRow("Image Path", info.imagePath ?? "N/A"),
                      const SizedBox(height: 12),
                      _buildDebugRow("File Size", info.fileSize != null ? "${(info.fileSize! / 1024).toStringAsFixed(1)} KB (${info.fileSize} bytes)" : "N/A"),
                      const SizedBox(height: 12),
                      _buildDebugRow("Image Dimensions", info.width != null ? "${info.width} x ${info.height}" : "N/A"),
                      const SizedBox(height: 12),
                      _buildDebugRow("Detected Barcodes Count", "${info.detectedCount}"),
                      const SizedBox(height: 12),
                      _buildDebugRow("Raw Barcode Value", info.rawBarcodeValue ?? "None Detected"),
                      const SizedBox(height: 12),
                      _buildDebugRow("Mime Type", info.mimeType ?? "N/A"),
                      if (info.zxingImageBase64 != null) ...[
                        const SizedBox(height: 16),
                        const Text(
                          "EXACT IMAGE PASSED TO SCANNER",
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                            color: AppTheme.accentCyan,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          height: 180,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.glassBorder),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(
                              base64Decode(info.zxingImageBase64!.startsWith('data:image/')
                                  ? info.zxingImageBase64!.substring(info.zxingImageBase64!.indexOf(',') + 1)
                                  : info.zxingImageBase64!),
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ],
                      if (info.exception != null) ...[
                        const SizedBox(height: 16),
                        const Text(
                          "SCANNER EXCEPTION LOG",
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                            color: AppTheme.accentCoral,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(maxHeight: 120),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.accentCoral.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.accentCoral.withOpacity(0.2)),
                          ),
                          child: SingleChildScrollView(
                            child: Text(
                              info.exception!,
                              style: const TextStyle(
                                color: AppTheme.accentCoral,
                                fontSize: 10,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDebugRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.02),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.glassBorder),
          ),
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: 500,
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            decoration: BoxDecoration(
              color: isDark
                  ? AppTheme.obsidianBackground.withOpacity(0.95)
                  : Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isDark
                    ? AppTheme.glassBorder
                    : Colors.black.withOpacity(0.08),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accentCyan.withOpacity(0.12),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
              ],
            ),
            padding: const EdgeInsets.all(24),
            child: _isLoading
                ? _buildLoadingState(isDark)
                : _showReview
                    ? _buildReviewScreen(isDark)
                    : _buildMethodChooser(isDark),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState(bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
        SizedBox(
          width: 60,
          height: 60,
          child: CircularProgressIndicator(
            color: AppTheme.accentCyan,
            strokeWidth: 4,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          _loadingText,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isDark ? Colors.white : AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          "This might take a few seconds...",
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
          ),
        ),
        if (_selectedImageBase64 != null &&
            _selectedImageBase64!.isNotEmpty &&
            !_selectedImageBase64!.startsWith('http')) ...[
          const SizedBox(height: 20),
          const Text(
            "PREVIEWING IMAGE TO BE DECODED",
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
              color: AppTheme.accentCyan,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.glassBorder),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: () {
                try {
                  String cleaned = _selectedImageBase64!;
                  final commaIndex = cleaned.indexOf(',');
                  if (commaIndex != -1) {
                    cleaned = cleaned.substring(commaIndex + 1);
                  }
                  return Image.memory(
                    base64Decode(cleaned),
                    fit: BoxFit.contain,
                  );
                } catch (e) {
                  return Center(
                    child: Text(
                      "Error loading preview: $e",
                      style: const TextStyle(color: AppTheme.accentCoral, fontSize: 11),
                    ),
                  );
                }
              }(),
            ),
          ),
        ],
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildMethodChooser(bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title block
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Food Log system',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    color: isDark ? Colors.white : AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Select a method to analyze your meal',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.04)
                      : Colors.black.withOpacity(0.04),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: AppTheme.textSecondary,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Custom Tab Bar styling
        Container(
          height: 52,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.03)
                : Colors.black.withOpacity(0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? AppTheme.glassBorder
                  : Colors.black.withOpacity(0.05),
            ),
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accentCyan.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            labelColor: Colors.black,
            unselectedLabelColor: AppTheme.textSecondary,
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(icon: Icon(Icons.qr_code_scanner_rounded, size: 20)),
              Tab(icon: Icon(Icons.camera_alt_rounded, size: 20)),
              Tab(icon: Icon(Icons.mic_rounded, size: 20)),
              Tab(icon: Icon(Icons.edit_note_rounded, size: 20)),
            ],
          ),
        ),
        const SizedBox(height: 20),

        if (_errorMessage != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.accentCoral.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.accentCoral.withOpacity(0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: AppTheme.accentCoral, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: AppTheme.accentCoral,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_errorMessage!.contains("Could not read any barcode") && ImagePickerHelper.lastDebugInfo != null) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _showBarcodeDebugDialog(context),
                      icon: const Icon(Icons.bug_report_rounded, color: AppTheme.accentCyan, size: 16),
                      label: const Text(
                        "View Scanner Debug Info",
                        style: TextStyle(
                          color: AppTheme.accentCyan,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        backgroundColor: Colors.white.withOpacity(0.04),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: AppTheme.accentCyan.withOpacity(0.3)),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Tab views container
        Flexible(
          child: SingleChildScrollView(
            child: SizedBox(
              height: 350,
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildBarcodeFlow(isDark),
                  _buildPhotoFlow(isDark),
                  _buildVoiceFlow(isDark),
                  _buildTextFlow(isDark),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Flow Views
  Widget _buildBarcodeFlow(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Camera Viewport
        Center(
          child: Container(
            width: double.infinity,
            height: 180,
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppTheme.glassBorder : Colors.black.withOpacity(0.08),
                width: 1.5,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (_isCameraInitialized && _cameraController != null)
                    Positioned.fill(
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: _cameraController!.value.previewSize?.height ?? 240,
                          height: _cameraController!.value.previewSize?.width ?? 320,
                          child: CameraPreview(_cameraController!),
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.videocam_off_rounded,
                            size: 32,
                            color: _errorMessage != null ? AppTheme.accentCoral.withOpacity(0.8) : AppTheme.textSecondary.withOpacity(0.4),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _errorMessage != null ? _errorMessage! : "Starting camera...",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _errorMessage != null ? AppTheme.accentCoral : AppTheme.textSecondary,
                              fontSize: 12,
                              fontWeight: _errorMessage != null ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Neon guidelines overlay box
                  Container(
                    width: 220,
                    height: 100,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppTheme.accentCyan.withOpacity(0.8),
                        width: 2.0,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),

                  // Small helper text on camera
                  Positioned(
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        "Align barcode inside guidelines",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  // Loader overlay
                  if (_isProcessingFrame || _isLoading)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withOpacity(0.55),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const CircularProgressIndicator(
                                color: AppTheme.accentCyan,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _isLoading ? _loadingText : "Decoding frame...",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Action Buttons Row
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  ImagePickerHelper.pickImage((base64, name, filePath) {
                    _runBarcodeImageScan(base64, name, filePath: filePath);
                  }, isBarcode: true, fromCamera: false);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? AppTheme.glassBorder : Colors.black.withOpacity(0.1),
                      width: 1.0,
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.photo_library_rounded, color: AppTheme.accentCyan, size: 16),
                      SizedBox(width: 6),
                      Text(
                        "Upload Image",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: _runAssetBarcodeScan,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.accentCyan.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.accentCyan.withOpacity(0.2),
                      width: 1.0,
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bug_report_rounded, color: AppTheme.accentCyan, size: 16),
                      SizedBox(width: 6),
                      Text(
                        "Test Asset",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Manual text field for backup entry
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 38,
                child: TextField(
                  controller: _barcodeController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 12),
                  decoration: InputDecoration(
                    hintText: "Or type barcode number...",
                    hintStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                    filled: true,
                    fillColor: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: AppTheme.glassBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: AppTheme.glassBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppTheme.accentCyan),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _runBarcodeScan(_barcodeController.text),
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Icon(Icons.arrow_forward_rounded, color: Colors.black, size: 18),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }


  Widget _buildPhotoFlow(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "AI PHOTO SCAN",
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Center(
            child: GestureDetector(
              onTap: () {
                ImagePickerHelper.pickImage((base64, name, filePath) {
                  setState(() {
                    _selectedImageBase64 = base64;
                  });
                  _runGeminiAnalysis('image', base64);
                });
              },
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.02)
                      : Colors.black.withOpacity(0.02),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark
                        ? AppTheme.glassBorder
                        : Colors.black.withOpacity(0.08),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.accentCyan.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.add_photo_alternate_rounded,
                        color: AppTheme.accentCyan,
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _selectedImageBase64 != null
                          ? "Image Uploaded!"
                          : "Upload Food Image",
                      style: TextStyle(
                        color: isDark ? Colors.white : AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Supported formats: JPG, PNG",
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVoiceFlow(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "VOICE INPUT",
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            GestureDetector(
              onTap: _speechAvailable
                  ? (_isListening ? _stopListening : _startListening)
                  : null,
              child: Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isListening
                      ? AppTheme.accentCoral.withOpacity(0.15)
                      : AppTheme.accentPurple.withOpacity(0.15),
                  border: Border.all(
                    color: _isListening ? AppTheme.accentCoral : AppTheme.accentPurple,
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                  color: _isListening ? AppTheme.accentCoral : AppTheme.accentPurple,
                  size: 26,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                height: 54,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.02)
                      : Colors.black.withOpacity(0.02),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? AppTheme.glassBorder
                        : Colors.black.withOpacity(0.08),
                  ),
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _voiceTranscript.isNotEmpty
                        ? _voiceTranscript
                        : _isListening
                            ? "Listening..."
                            : "Tap mic to speak meal...",
                    style: TextStyle(
                      color: _voiceTranscript.isNotEmpty
                          ? (isDark ? Colors.white : AppTheme.textPrimary)
                          : AppTheme.textSecondary,
                      fontSize: 13,
                      fontStyle: _voiceTranscript.isNotEmpty
                          ? FontStyle.normal
                          : FontStyle.italic,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          "Or pick a sample voice input:",
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _sampleVoiceInputs.map((sample) {
            return ActionChip(
              backgroundColor: isDark
                  ? Colors.white.withOpacity(0.04)
                  : Colors.black.withOpacity(0.03),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: isDark
                      ? AppTheme.glassBorder
                      : Colors.black.withOpacity(0.08),
                ),
              ),
              label: Text(
                '"$sample"',
                style: TextStyle(
                  color: isDark ? Colors.white : AppTheme.textPrimary,
                  fontSize: 11,
                ),
              ),
              onPressed: () {
                setState(() => _voiceTranscript = sample);
                _runGeminiAnalysis('voice', sample);
              },
            );
          }).toList(),
        ),
        const Spacer(),
        GestureDetector(
          onTap: _voiceTranscript.isEmpty
              ? null
              : () => _runGeminiAnalysis('voice', _voiceTranscript),
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              gradient: _voiceTranscript.isEmpty
                  ? null
                  : AppTheme.primaryGradient,
              color: _voiceTranscript.isEmpty
                  ? Colors.white.withOpacity(0.04)
                  : null,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                "Analyze Spoken Meal",
                style: TextStyle(
                  color: _voiceTranscript.isEmpty
                      ? AppTheme.textSecondary
                      : Colors.black,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextFlow(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "TEXT INPUT",
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _textDescriptionController,
          maxLines: 2,
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
          decoration: InputDecoration(
            hintText: "Type what you ate (e.g. 2 eggs and a banana)...",
            hintStyle: const TextStyle(color: AppTheme.textSecondary),
            filled: true,
            fillColor: isDark
                ? Colors.white.withOpacity(0.02)
                : Colors.black.withOpacity(0.02),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: isDark
                    ? AppTheme.glassBorder
                    : Colors.black.withOpacity(0.1),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: isDark
                    ? AppTheme.glassBorder
                    : Colors.black.withOpacity(0.1),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppTheme.accentCyan),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          "Or click a sample description:",
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _sampleTextInputs.map((sample) {
            return ActionChip(
              backgroundColor: isDark
                  ? Colors.white.withOpacity(0.04)
                  : Colors.black.withOpacity(0.03),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: isDark
                      ? AppTheme.glassBorder
                      : Colors.black.withOpacity(0.08),
                ),
              ),
              label: Text(
                sample,
                style: TextStyle(
                  color: isDark ? Colors.white : AppTheme.textPrimary,
                  fontSize: 11,
                ),
              ),
              onPressed: () {
                _textDescriptionController.text = sample;
                _runGeminiAnalysis('text', sample);
              },
            );
          }).toList(),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () =>
              _runGeminiAnalysis('text', _textDescriptionController.text),
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accentCyan.withOpacity(0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Center(
              child: Text(
                "Analyze Meal Description",
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySelector(bool isDark) {
    final categories = [
      {'name': 'Breakfast', 'key': 'breakfast_cal', 'icon': Icons.egg_rounded},
      {'name': 'Lunch', 'key': 'lunch_cal', 'icon': Icons.restaurant_rounded},
      {'name': 'Dinner', 'key': 'dinner_cal', 'icon': Icons.soup_kitchen_rounded},
      {'name': 'Snacks', 'key': 'snacks_cal', 'icon': Icons.bakery_dining_rounded},
      {'name': 'Eating Out', 'key': 'outside_food_cal', 'icon': Icons.delivery_dining_rounded},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'MEAL CATEGORY',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 38,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final cat = categories[index];
              final isSelected = _selectedMealKey == cat['key'];
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Row(
                    children: [
                      Icon(
                        cat['icon'] as IconData,
                        size: 14,
                        color: isSelected
                            ? Colors.black
                            : AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        cat['name'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? Colors.black
                              : (isDark ? Colors.white70 : AppTheme.textPrimary),
                        ),
                      ),
                    ],
                  ),
                  selected: isSelected,
                  selectedColor: AppTheme.accentCyan,
                  backgroundColor: isDark
                      ? Colors.white.withOpacity(0.03)
                      : Colors.black.withOpacity(0.03),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSelected
                          ? AppTheme.accentCyan
                          : (isDark
                              ? AppTheme.glassBorder
                              : Colors.black.withOpacity(0.08)),
                    ),
                  ),
                  showCheckmark: false,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedMealKey = cat['key'] as String;
                      });
                    }
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildReviewScreen(bool isDark) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Review Screen',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      color: AppTheme.accentEmerald,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Confirm or edit nutrition details',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              // Add a back button to switch back to selector if needed
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded,
                    color: AppTheme.textSecondary),
                onPressed: () {
                  setState(() {
                    _showReview = false;
                    _errorMessage = null;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Warning Notice Alert Card
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.03)
                  : Colors.black.withOpacity(0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? AppTheme.glassBorder
                    : Colors.black.withOpacity(0.08),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: AppTheme.accentCyan, size: 16),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    "Nutritional values are estimates. Review & edit below.",
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Food Name Editable Row
          const Text(
            'FOOD NAME',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _reviewNameController,
            style: TextStyle(
              color: isDark ? Colors.white : AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: isDark
                  ? Colors.white.withOpacity(0.02)
                  : Colors.black.withOpacity(0.02),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: isDark
                      ? AppTheme.glassBorder
                      : Colors.black.withOpacity(0.1),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: isDark
                      ? AppTheme.glassBorder
                      : Colors.black.withOpacity(0.1),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppTheme.accentCyan),
              ),
            ),
          ),
          if (_selectedImageBase64 != null && _selectedImageBase64!.isNotEmpty) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                height: 180,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.white.withOpacity(0.06),
                  ),
                ),
                child: () {
                  final imgStr = _selectedImageBase64!;
                  if (imgStr.startsWith('http')) {
                    return Image.network(imgStr, fit: BoxFit.cover);
                  }
                  try {
                    String cleaned = imgStr;
                    final commaIndex = cleaned.indexOf(',');
                    if (commaIndex != -1) {
                      cleaned = cleaned.substring(commaIndex + 1);
                    }
                    cleaned = cleaned.replaceAll(RegExp(r'\s+'), '');
                    return Image.memory(base64Decode(cleaned), fit: BoxFit.cover);
                  } catch (e) {
                    return const Center(
                      child: Icon(Icons.broken_image_rounded, color: AppTheme.accentCoral),
                    );
                  }
                }(),
              ),
            ),
          ],
          const SizedBox(height: 20),
          _buildCategorySelector(isDark),
          const SizedBox(height: 20),

          // Calories detail Bento Box
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
            decoration: BoxDecoration(
              color: AppTheme.accentCyan.withOpacity(0.06),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppTheme.accentCyan.withOpacity(0.2),
                width: 1.2,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.accentCyan.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.local_fire_department_rounded,
                        color: AppTheme.accentCyan,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'CALORIES',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                        Text(
                          'Energy Intake',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(
                  width: 90,
                  child: TextField(
                    controller: _reviewCalController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      suffixText: ' kcal',
                      suffixStyle: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Macros Grid Row
          Row(
            children: [
              // Protein Item
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.accentOrange.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppTheme.accentOrange.withOpacity(0.2),
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.egg_rounded,
                          color: AppTheme.accentOrange, size: 16),
                      const SizedBox(height: 6),
                      const Text(
                        'PROTEIN',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 32,
                            child: TextField(
                              controller: _reviewProteinController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          const Text(
                            'g',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Carbs Item
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.accentCyan.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppTheme.accentCyan.withOpacity(0.2),
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.bakery_dining_rounded,
                          color: AppTheme.accentCyan, size: 16),
                      const SizedBox(height: 6),
                      const Text(
                        'CARBS',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 32,
                            child: TextField(
                              controller: _reviewCarbsController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          const Text(
                            'g',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Fat Item
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.accentCoral.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppTheme.accentCoral.withOpacity(0.2),
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.water_drop_rounded,
                          color: AppTheme.accentCoral, size: 16),
                      const SizedBox(height: 6),
                      const Text(
                        'FAT',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 32,
                            child: TextField(
                              controller: _reviewFatController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          const Text(
                            'g',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Log Action button
          GestureDetector(
            onTap: () {
              // Assemble the updated Standard Food Object from review TextFields
              final finalFood = StandardFood(
                foodName: _reviewNameController.text.trim().isNotEmpty
                    ? _reviewNameController.text.trim()
                    : "Unknown Meal",
                calories: int.tryParse(_reviewCalController.text) ?? 0,
                protein: int.tryParse(_reviewProteinController.text) ?? 0,
                carbs: int.tryParse(_reviewCarbsController.text) ?? 0,
                fat: int.tryParse(_reviewFatController.text) ?? 0,
              );

              debugPrint("Logged Food Object: ${jsonEncode(finalFood.toJson())}");
              debugPrint("DIALOG DONE: _selectedImageBase64 length: ${_selectedImageBase64?.length ?? 0}");

              // Save to Riverpod dailyMetricsProvider
              final selectedDate = ref.read(selectedDateProvider);
              ref.read(dailyMetricsProvider(selectedDate).notifier).logMeal(
                    mealKey: _selectedMealKey,
                    calories: finalFood.calories,
                    protein: finalFood.protein,
                    carbs: finalFood.carbs,
                    fat: finalFood.fat,
                    foodName: finalFood.foodName,
                    imageUrl: _selectedImageBase64,
                  );

              // Display confirmation snackbar/toast via ScaffoldMessenger
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: AppTheme.accentEmerald,
                  content: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Colors.black),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Successfully Logged: ${finalFood.foodName}!",
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );

              Navigator.of(context).pop();
            },
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.accentEmerald, AppTheme.accentEmerald],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accentEmerald.withOpacity(0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  "Done",
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
