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
import '../../core/theme.dart';
import '../../core/widgets/zivo_loader.dart';
import '../../services/ai_backend_service.dart';
import '../../services/state_providers.dart';
import '../../services/storage_service.dart';
import '../../utils/image_picker_helper.dart';
import '../../services/scanner/native_barcode_scanner.dart';
import '../../services/scanner/ai_analysis_service.dart';
import '../../services/firebase_service.dart';

class BreakdownItem {
  String name;
  double servingSize;
  String servingUnit;
  int calories;
  int protein;
  int carbs;
  int fat;

  BreakdownItem({
    required this.name,
    required this.servingSize,
    required this.servingUnit,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'servingSize': servingSize,
        'servingUnit': servingUnit,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
      };

  factory BreakdownItem.fromJson(Map<String, dynamic> json) {
    return BreakdownItem(
      name: json['name'] ?? json['foodName'] ?? 'Ingredient',
      servingSize: json['servingSize'] != null ? (json['servingSize'] as num).toDouble() : 1.0,
      servingUnit: json['servingUnit'] ?? 'piece',
      calories: (json['calories'] ?? 0).toInt(),
      protein: (json['protein'] ?? 0).toInt(),
      carbs: (json['carbs'] ?? 0).toInt(),
      fat: (json['fat'] ?? 0).toInt(),
    );
  }
}

class StandardFood {
  String foodName;
  int calories;
  int protein;
  int carbs;
  int fat;
  double? servingSize;
  String? servingUnit;
  List<BreakdownItem> items;

  StandardFood({
    required this.foodName,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.servingSize,
    this.servingUnit,
    List<BreakdownItem>? items,
  }) : items = items ?? [];

  Map<String, dynamic> toJson() => {
        'foodName': foodName,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        if (servingSize != null) 'servingSize': servingSize,
        if (servingUnit != null) 'servingUnit': servingUnit,
        'items': items.map((e) => e.toJson()).toList(),
      };
}

class FoodLoggerDialog extends ConsumerStatefulWidget {
  final int initialTab;
  final String? initialImageBase64;
  final bool autoStartVoice;
  const FoodLoggerDialog({
    super.key,
    this.initialTab = 0,
    this.initialImageBase64,
    this.autoStartVoice = false,
  });

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

  // Baseline values for auto-scaling
  double _baselineServingSize = 1.0;
  int _baselineCal = 0;
  int _baselineProtein = 0;
  int _baselineCarbs = 0;
  int _baselineFat = 0;
  bool _isAutoScaling = false;

  // Focus nodes for keyboard auto-opening
  final FocusNode _describeFocusNode = FocusNode();
  final FocusNode _manualFocusNode = FocusNode();

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
  String _lastAnalysisType = 'image';
  String _lastAnalysisContent = '';

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
  final TextEditingController _reviewServingSizeController = TextEditingController(text: "1");
  String _reviewSelectedServingUnit = 'serving';
  List<BreakdownItem> _reviewBreakdownItems = [];
  List<BreakdownItem> _manualBreakdownItems = [];
  bool _showReviewBreakdown = false;
  bool _showManualBreakdown = false;

  // Manual flow controllers
  final TextEditingController _manualNameController = TextEditingController();
  final TextEditingController _manualCalController = TextEditingController();
  final TextEditingController _manualProteinController = TextEditingController();
  final TextEditingController _manualCarbsController = TextEditingController();
  final TextEditingController _manualFatController = TextEditingController();
  final TextEditingController _manualServingSizeController = TextEditingController(text: "1");
  String _selectedServingUnit = 'serving';
  final List<String> _servingUnits = ['grams', 'ml', 'serving', 'piece', 'bowl', 'cup', 'scoop'];

  String _normalizeServingUnit(String? rawUnit) {
    if (rawUnit == null || rawUnit.isEmpty) return 'serving';
    final clean = rawUnit.trim().toLowerCase();

    // Direct match check first
    for (final unit in _servingUnits) {
      if (clean == unit) return unit;
    }

    // Common abbreviations/plurals mappings
    if (clean == 'g' || clean == 'gram' || clean == 'grams' || clean.startsWith('g/')) {
      return 'grams';
    }
    if (clean == 'ml' || clean == 'mls' || clean.contains('milliliter') || clean.contains('litre') || clean.contains('liter')) {
      return 'ml';
    }
    if (clean == 'piece' || clean == 'pieces' || clean == 'pcs' || clean == 'pc') {
      return 'piece';
    }
    if (clean == 'bowl' || clean == 'bowls') {
      return 'bowl';
    }
    if (clean == 'cup' || clean == 'cups') {
      return 'cup';
    }
    if (clean == 'scoop' || clean == 'scoops') {
      return 'scoop';
    }
    if (clean == 'serving' || clean == 'servings') {
      return 'serving';
    }

    // Map common food units to closest matching standard units
    if (clean == 'slice' || clean == 'slices' || clean == 'loaf' || clean == 'loaves') {
      return 'piece';
    }
    if (clean == 'glass' || clean == 'glasses' || clean == 'bottle' || clean == 'bottles' || clean == 'can' || clean == 'cans') {
      return 'cup';
    }
    if (clean == 'plate' || clean == 'plates' || clean == 'dish' || clean == 'dishes') {
      return 'bowl';
    }
    if (clean == 'tbsp' || clean == 'tablespoon' || clean == 'tablespoons' || clean == 'tsp' || clean == 'teaspoon' || clean == 'teaspoons') {
      return 'serving';
    }

    return clean;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this, initialIndex: widget.initialTab);
    _tabController.addListener(_handleTabSelection);
    _reviewServingSizeController.addListener(_onServingSizeChanged);
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

    if (widget.initialImageBase64 != null) {
      _selectedImageBase64 = widget.initialImageBase64;
      Future.microtask(() {
        _runGeminiAnalysis('image', widget.initialImageBase64!);
      });
    }

    if (widget.autoStartVoice) {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) {
          _startListening();
        }
      });
    }

    if (widget.initialTab == 3) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) {
          _describeFocusNode.requestFocus();
        }
      });
    } else if (widget.initialTab == 4) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) {
          _manualFocusNode.requestFocus();
        }
      });
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    _describeFocusNode.dispose();
    _manualFocusNode.dispose();
    _barcodeController.dispose();
    _textDescriptionController.dispose();
    _manualNameController.dispose();
    _manualCalController.dispose();
    _manualProteinController.dispose();
    _manualCarbsController.dispose();
    _manualFatController.dispose();
    _reviewServingSizeController.removeListener(_onServingSizeChanged);
    _reviewServingSizeController.dispose();
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
        if (_isLoading || _isProcessingFrame || !mounted || _tabController.index != 1 || _showReview || _cameraController == null || !_isCameraInitialized || !_cameraController!.value.isInitialized) return;
        _isProcessingFrame = true;
        try {
          final XFile file = await _cameraController!.takePicture();
          if (!mounted || _cameraController == null || !_isCameraInitialized) {
            _isProcessingFrame = false;
            return;
          }
          final bytes = await file.readAsBytes();
          final base64Str = base64Encode(bytes);
          final extension = file.path.split('.').last.toLowerCase();
          final mimeType = (extension == 'png') ? 'image/png' : 'image/jpeg';
          final dataUrl = "data:$mimeType;base64,$base64Str";

          final barcode = await ImagePickerHelper.scanBarcode(dataUrl);
          if (barcode.isNotEmpty && !barcode.startsWith('ERROR') && mounted) {
            _isProcessingFrame = true;
            await _runBarcodeScan(barcode);
            _isProcessingFrame = false;
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
        if (_isLoading || _isProcessingFrame || !mounted || _tabController.index != 1 || _showReview) return;
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
    if (_tabController.index == 1) {
      if (_cameraController == null) {
        _initializeCamera();
      }
    } else {
      _disposeCamera();
    }
    if (_tabController.index == 3) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && _tabController.index == 3) {
          _describeFocusNode.requestFocus();
        }
      });
    } else if (_tabController.index == 4) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && _tabController.index == 4) {
          _manualFocusNode.requestFocus();
        }
      });
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

      // Smart Parse serving size and unit!
      String queryText = _selectedFood!.foodName;
      if (_lastAnalysisType != 'image' && _lastAnalysisContent.isNotEmpty) {
        queryText = _lastAnalysisContent;
      }
      final parsed = _parseServingInfo(queryText);
      final double parsedSize = parsed['size'];
      double initialSize = _selectedFood!.servingSize ?? parsedSize;
      if (parsedSize > 1.0 && (_selectedFood!.servingSize == null || _selectedFood!.servingSize == 1.0)) {
        initialSize = parsedSize;
      }
      final String rawUnit = _selectedFood!.servingUnit ?? parsed['unit'];
      final String initialUnit = _normalizeServingUnit(rawUnit);

      _isAutoScaling = true;
      _reviewServingSizeController.text = initialSize % 1 == 0 
          ? initialSize.toInt().toString() 
          : initialSize.toString();
      _reviewSelectedServingUnit = initialUnit;
      _isAutoScaling = false;

      // Copy breakdown items
      _reviewBreakdownItems = List<BreakdownItem>.from(_selectedFood!.items);

      // Initialize baselines
      _baselineServingSize = initialSize > 0 ? initialSize : 1.0;
      _baselineCal = _selectedFood!.calories;
      _baselineProtein = _selectedFood!.protein;
      _baselineCarbs = _selectedFood!.carbs;
      _baselineFat = _selectedFood!.fat;
      
      // Auto-recalculate totals if items were loaded
      _showReviewBreakdown = _reviewBreakdownItems.isNotEmpty;
      if (_reviewBreakdownItems.isNotEmpty) {
        _updateTotalsFromBreakdown();
      }
    }
  }

  void _updateTotalsFromBreakdown() {
    if (_reviewBreakdownItems.isEmpty) return;
    int totalCals = 0;
    int totalProtein = 0;
    int totalCarbs = 0;
    int totalFat = 0;
    for (final item in _reviewBreakdownItems) {
      totalCals += item.calories;
      totalProtein += item.protein;
      totalCarbs += item.carbs;
      totalFat += item.fat;
    }
    setState(() {
      _reviewCalController.text = totalCals.toString();
      _reviewProteinController.text = totalProtein.toString();
      _reviewCarbsController.text = totalCarbs.toString();
      _reviewFatController.text = totalFat.toString();
    });
  }

  void _updateManualTotalsFromBreakdown() {
    if (_manualBreakdownItems.isEmpty) return;
    int totalCals = 0;
    int totalProtein = 0;
    int totalCarbs = 0;
    int totalFat = 0;
    for (final item in _manualBreakdownItems) {
      totalCals += item.calories;
      totalProtein += item.protein;
      totalCarbs += item.carbs;
      totalFat += item.fat;
    }
    setState(() {
      _manualCalController.text = totalCals.toString();
      _manualProteinController.text = totalProtein.toString();
      _manualCarbsController.text = totalCarbs.toString();
      _manualFatController.text = totalFat.toString();
    });
  }

  void _showEditBreakdownItemDialog(BreakdownItem? item, int? index, {bool isManual = false}) {
    final nameCtrl = TextEditingController(text: item?.name ?? '');
    final sizeCtrl = TextEditingController(text: item != null ? (item.servingSize % 1 == 0 ? item.servingSize.toInt().toString() : item.servingSize.toString()) : '1');
    final calCtrl = TextEditingController(text: item?.calories.toString() ?? '0');
    final proCtrl = TextEditingController(text: item?.protein.toString() ?? '0');
    final carbCtrl = TextEditingController(text: item?.carbs.toString() ?? '0');
    final fatCtrl = TextEditingController(text: item?.fat.toString() ?? '0');

    final dialogUnits = List<String>.from(_servingUnits);
    String selectedUnit = item?.servingUnit ?? 'piece';
    if (!dialogUnits.contains(selectedUnit)) {
      dialogUnits.add(selectedUnit);
    }

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final title = item == null ? "Add Breakdown Item" : "Edit Item";
        return Dialog(
          backgroundColor: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: StatefulBuilder(
                builder: (context, dialogSetState) {
                  return Container(
                    constraints: const BoxConstraints(maxWidth: 400),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1C1E1B) : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isDark ? const Color(0xFF323530) : AppTheme.glassBorder,
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
                              Text(
                                title,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? Colors.white : AppTheme.textPrimary,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.question_mark_rounded, color: AppTheme.accentCyan, size: 20),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () {
                                  showDialog(
                                    context: ctx,
                                    builder: (infoCtx) => Dialog(
                                      backgroundColor: Colors.transparent,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(20),
                                        child: BackdropFilter(
                                          filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                                          child: Container(
                                            constraints: const BoxConstraints(maxWidth: 320),
                                            padding: const EdgeInsets.all(20),
                                            decoration: BoxDecoration(
                                              color: isDark ? const Color(0xFF000000) : Colors.white.withOpacity(0.95),
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(
                                                color: isDark ? const Color(0xFF323530) : AppTheme.glassBorder,
                                              ),
                                            ),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    const Icon(Icons.info_outline_rounded, color: AppTheme.accentCyan, size: 22),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      "Breakdown Item Help",
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 16,
                                                        color: isDark ? Colors.white : AppTheme.textPrimary,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 16),
                                                Text(
                                                  "Breakdown items let you log individual ingredients of a meal (e.g. eggs, oil, vegetables).\n\n"
                                                  "Entering their specific portion size, unit, calories, and macros helps the app calculate the overall nutrition of the meal more accurately.",
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: isDark ? Colors.white70 : AppTheme.textSecondary,
                                                    height: 1.4,
                                                  ),
                                                ),
                                                const SizedBox(height: 20),
                                                Align(
                                                  alignment: Alignment.centerRight,
                                                  child: TextButton(
                                                    onPressed: () => Navigator.pop(infoCtx),
                                                    child: const Text("Got it", style: TextStyle(color: AppTheme.accentCyan, fontWeight: FontWeight.bold)),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: nameCtrl,
                            decoration: InputDecoration(
                              labelText: "Item Name",
                              hintText: "e.g. Scrambled Eggs",
                              labelStyle: const TextStyle(color: AppTheme.textSecondary),
                              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black12)),
                              focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.accentCyan)),
                            ),
                            style: TextStyle(color: isDark ? Colors.white : Colors.black),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: sizeCtrl,
                                  decoration: InputDecoration(
                                    labelText: "Size",
                                    labelStyle: const TextStyle(color: AppTheme.textSecondary),
                                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black12)),
                                    focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.accentCyan)),
                                  ),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: selectedUnit,
                                  dropdownColor: isDark ? const Color(0xFF1C1E1B) : Colors.white,
                                  style: TextStyle(
                                    color: isDark ? Colors.white : Colors.black,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: "Unit",
                                    labelStyle: const TextStyle(color: AppTheme.textSecondary),
                                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black12)),
                                    focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.accentCyan)),
                                  ),
                                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.accentCyan),
                                  items: dialogUnits.map((String val) {
                                    return DropdownMenuItem<String>(
                                      value: val,
                                      child: Text(val),
                                    );
                                  }).toList(),
                                  onChanged: (String? newVal) {
                                    if (newVal != null) {
                                      dialogSetState(() {
                                        selectedUnit = newVal;
                                      });
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: calCtrl,
                            decoration: InputDecoration(
                              labelText: "Calories (kcal)",
                              labelStyle: const TextStyle(color: AppTheme.textSecondary),
                              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black12)),
                              focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.accentCyan)),
                            ),
                            keyboardType: TextInputType.number,
                            style: TextStyle(color: isDark ? Colors.white : Colors.black),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: proCtrl,
                                  decoration: InputDecoration(
                                    labelText: "Protein (g)",
                                    labelStyle: const TextStyle(color: AppTheme.textSecondary),
                                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black12)),
                                    focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.accentCyan)),
                                  ),
                                  keyboardType: TextInputType.number,
                                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: carbCtrl,
                                  decoration: InputDecoration(
                                    labelText: "Carbs (g)",
                                    labelStyle: const TextStyle(color: AppTheme.textSecondary),
                                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black12)),
                                    focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.accentCyan)),
                                  ),
                                  keyboardType: TextInputType.number,
                                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: fatCtrl,
                                  decoration: InputDecoration(
                                    labelText: "Fat (g)",
                                    labelStyle: const TextStyle(color: AppTheme.textSecondary),
                                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black12)),
                                    focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.accentCyan)),
                                  ),
                                  keyboardType: TextInputType.number,
                                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text("Cancel", style: TextStyle(color: AppTheme.textSecondary)),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton(
                                onPressed: () {
                                  final nameVal = nameCtrl.text.trim();
                                  if (nameVal.isEmpty) return;
                                  final sizeVal = double.tryParse(sizeCtrl.text) ?? 1.0;
                                  final calVal = int.tryParse(calCtrl.text) ?? 0;
                                  final proVal = int.tryParse(proCtrl.text) ?? 0;
                                  final carbVal = int.tryParse(carbCtrl.text) ?? 0;
                                  final fatVal = int.tryParse(fatCtrl.text) ?? 0;

                                  final newItem = BreakdownItem(
                                    name: nameVal,
                                    servingSize: sizeVal,
                                    servingUnit: selectedUnit,
                                    calories: calVal,
                                    protein: proVal,
                                    carbs: carbVal,
                                    fat: fatVal,
                                  );

                                  setState(() {
                                    if (isManual) {
                                      if (item != null && index != null) {
                                        _manualBreakdownItems[index] = newItem;
                                      } else {
                                        _manualBreakdownItems.add(newItem);
                                      }
                                    } else {
                                      if (item != null && index != null) {
                                        _reviewBreakdownItems[index] = newItem;
                                      } else {
                                        _reviewBreakdownItems.add(newItem);
                                      }
                                    }
                                  });
                                  if (isManual) {
                                    _updateManualTotalsFromBreakdown();
                                  } else {
                                    _updateTotalsFromBreakdown();
                                  }
                                  Navigator.pop(ctx);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.accentCyan,
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text("Save", style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  void _showInstructionsBottomSheet(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0E0F0C) : Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
            border: Border.all(
              color: isDark ? const Color(0xFF323530) : AppTheme.glassBorder,
              width: 1,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.help_outline_rounded, color: AppTheme.accentCyan, size: 26),
                  const SizedBox(width: 10),
                  Text(
                    "Food Log Instructions",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                "Track your nutrition using 6 flexible methods:",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildInstructionItem(
                        icon: Icons.camera_alt_rounded,
                        title: "1. Photo Scan",
                        desc: "Capture or upload a meal photo. AI automatically logs the ingredients, serving sizes, calories, and macros.",
                        isDark: isDark,
                      ),
                      _buildInstructionItem(
                        icon: Icons.qr_code_scanner_rounded,
                        title: "2. Barcode Scanner",
                        desc: "Scan a barcode to instantly fetch and log product nutritional facts from OpenFoodFacts.",
                        isDark: isDark,
                      ),
                      _buildInstructionItem(
                        icon: Icons.mic_rounded,
                        title: "3. Voice Logger",
                        desc: "Log food by speaking naturally (e.g., '1 bowl of oatmeal with milk'). AI parses the speech to populate your log.",
                        isDark: isDark,
                      ),
                      _buildInstructionItem(
                        icon: Icons.edit_note_rounded,
                        title: "4. Natural Language Description",
                        desc: "Type out a description of your meal and let the AI estimate the calories and macros dynamically.",
                        isDark: isDark,
                      ),
                      _buildInstructionItem(
                        icon: Icons.post_add_rounded,
                        title: "5. Manual Entry & Breakdown",
                        desc: "Directly enter meal details, or list specific ingredients under breakdown to calculate total macros automatically.",
                        isDark: isDark,
                      ),
                      _buildInstructionItem(
                        icon: Icons.bookmarks_rounded,
                        title: "6. Presets",
                        desc: "Save your favorite meals as custom presets and log them instantly with a single tap.",
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentCyan,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text("Got it, Let's Log!", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInstructionItem({
    required IconData icon,
    required String title,
    required String desc,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppTheme.accentCyan, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: isDark ? Colors.white60 : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEditPresetDialog(Map<String, dynamic> preset) {
    final oldName = preset['name'] ?? 'Unnamed Preset';
    final nameCtrl = TextEditingController(text: oldName);
    final calCtrl = TextEditingController(text: (preset['calories'] ?? 0).toString());
    final proCtrl = TextEditingController(text: (preset['protein'] ?? 0).toString());
    final carbCtrl = TextEditingController(text: (preset['carbs'] ?? 0).toString());
    final fatCtrl = TextEditingController(text: (preset['fat'] ?? 0).toString());

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Dialog(
          backgroundColor: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0E0F0C) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark ? const Color(0xFF323530) : AppTheme.glassBorder,
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Edit Saved Preset",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: nameCtrl,
                        decoration: InputDecoration(
                          labelText: "Preset Name",
                          labelStyle: const TextStyle(color: AppTheme.textSecondary),
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black12)),
                          focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.accentCyan)),
                        ),
                        style: TextStyle(color: isDark ? Colors.white : Colors.black),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: calCtrl,
                        decoration: InputDecoration(
                          labelText: "Calories (kcal)",
                          labelStyle: const TextStyle(color: AppTheme.textSecondary),
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black12)),
                          focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.accentCyan)),
                        ),
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: isDark ? Colors.white : Colors.black),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: proCtrl,
                              decoration: InputDecoration(
                                labelText: "Protein (g)",
                                labelStyle: const TextStyle(color: AppTheme.textSecondary),
                                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black12)),
                                focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.accentCyan)),
                              ),
                              keyboardType: TextInputType.number,
                              style: TextStyle(color: isDark ? Colors.white : Colors.black),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: carbCtrl,
                              decoration: InputDecoration(
                                labelText: "Carbs (g)",
                                labelStyle: const TextStyle(color: AppTheme.textSecondary),
                                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black12)),
                                focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.accentCyan)),
                              ),
                              keyboardType: TextInputType.number,
                              style: TextStyle(color: isDark ? Colors.white : Colors.black),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: fatCtrl,
                              decoration: InputDecoration(
                                labelText: "Fat (g)",
                                labelStyle: const TextStyle(color: AppTheme.textSecondary),
                                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black12)),
                                focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.accentCyan)),
                              ),
                              keyboardType: TextInputType.number,
                              style: TextStyle(color: isDark ? Colors.white : Colors.black),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text("Cancel", style: TextStyle(color: AppTheme.textSecondary)),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () async {
                              final newName = nameCtrl.text.trim();
                              if (newName.isEmpty) return;

                              final newCals = int.tryParse(calCtrl.text) ?? 0;
                              final newPro = int.tryParse(proCtrl.text) ?? 0;
                              final newCarb = int.tryParse(carbCtrl.text) ?? 0;
                              final newFat = int.tryParse(fatCtrl.text) ?? 0;

                              if (oldName.toLowerCase() != newName.toLowerCase()) {
                                await StorageService.deleteFoodPreset(oldName);
                              }

                              await StorageService.saveFoodPreset({
                                'name': newName,
                                'calories': newCals,
                                'protein': newPro,
                                'carbs': newCarb,
                                'fat': newFat,
                                'items': preset['items'] ?? [],
                              });
                              FirebaseService.saveFoodPresetsCloud(StorageService.getFoodPresets());

                              if (mounted) {
                                setState(() {});
                              }
                              Navigator.pop(ctx);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accentCyan,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text("Save Changes", style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
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

  void _onServingSizeChanged() {
    if (_isAutoScaling || !_showReview) return;
    final text = _reviewServingSizeController.text.trim();
    if (text.isEmpty) return;
    final newSize = double.tryParse(text);
    if (newSize == null || newSize <= 0) return;

    final factor = newSize / (_baselineServingSize > 0 ? _baselineServingSize : 1.0);

    _isAutoScaling = true;
    setState(() {
      _reviewCalController.text = (_baselineCal * factor).round().toString();
      _reviewProteinController.text = (_baselineProtein * factor).round().toString();
      _reviewCarbsController.text = (_baselineCarbs * factor).round().toString();
      _reviewFatController.text = (_baselineFat * factor).round().toString();
    });
    _isAutoScaling = false;
  }

  Map<String, dynamic> _parseServingInfo(String text) {
    final cleanText = text.toLowerCase();
    double size = 1.0;
    String unit = 'serving';

    // 1. Detect unit
    if (cleanText.contains('gram') || cleanText.contains('g ') || cleanText.endsWith('g')) {
      unit = 'grams';
    } else if (cleanText.contains('ml') || cleanText.contains('milliliter') || cleanText.contains('litre')) {
      unit = 'ml';
    } else if (cleanText.contains('piece')) {
      unit = 'piece';
    } else if (cleanText.contains('bowl')) {
      unit = 'bowl';
    } else if (cleanText.contains('cup')) {
      unit = 'cup';
    } else if (cleanText.contains('scoop')) {
      unit = 'scoop';
    } else if (cleanText.contains('egg') || cleanText.contains('banana') || cleanText.contains('apple') || cleanText.contains('cookie') || cleanText.contains('dosa') || cleanText.contains('roti')) {
      unit = 'piece'; // Default common items to 'piece' instead of generic 'serving'
    }

    // 2. Detect size
    final wordNumbers = {
      'one': 1.0,
      'two': 2.0,
      'three': 3.0,
      'four': 4.0,
      'five': 5.0,
      'six': 6.0,
      'seven': 7.0,
      'eight': 8.0,
      'nine': 9.0,
      'ten': 10.0,
      'a': 1.0,
      'an': 1.0,
    };

    final numReg = RegExp(r'\b(\d+(\.\d+)?)\b');
    final match = numReg.firstMatch(cleanText);
    if (match != null) {
      size = double.tryParse(match.group(1)!) ?? 1.0;
    } else {
      final words = cleanText.split(RegExp(r'[^a-zA-Z]'));
      for (final word in words) {
        if (wordNumbers.containsKey(word)) {
          size = wordNumbers[word]!;
          break;
        }
      }
    }

    return {'size': size, 'unit': unit};
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
          'https://world.openfoodfacts.org/api/v2/product/$barcode.json');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final isSuccess = json['product'] != null;
        
        if (isSuccess) {
          final product = json['product'];
          final nutriments = product['nutriments'] ?? {};

          final name = product['product_name'] ?? 'Unknown Product';
          
          // Safely parse int/double/String values from nutriment list
          int _parseNutrient(List<String> keys) {
            for (var key in keys) {
              final val = nutriments[key];
              if (val != null) {
                if (val is num) return val.round();
                final parsed = double.tryParse(val.toString());
                if (parsed != null) return parsed.round();
              }
            }
            return 0;
          }

          final cal = _parseNutrient(['energy-kcal_100g', 'energy-kcal', 'energy-kcal_value', 'energy_value']);
          final prot = _parseNutrient(['proteins_100g', 'proteins', 'proteins_value']);
          final carb = _parseNutrient(['carbohydrates_100g', 'carbohydrates', 'carbohydrates_value']);
          final fat = _parseNutrient(['fat_100g', 'fat', 'fat_value']);

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
    } catch (e, stack) {
      debugPrint("Food Log Barcode lookup exception: $e\n$stack");
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
    _lastAnalysisType = type;
    _lastAnalysisContent = content;
    String optimizedContent = content;
    if (type == 'image') {
      setState(() {
        _isLoading = true;
        _loadingText = "Compressing image...";
        _errorMessage = null;
      });
      // Yield to let UI update and show "Compressing image..."
      await Future.delayed(const Duration(milliseconds: 100));
      try {
        // Run CPU-intensive visual compression in background isolate
        optimizedContent = await compute(AiAnalysisService.optimizeImage, content);
      } catch (e) {
        debugPrint("Food Log visual compression failed: $e");
      }
    }

    setState(() {
      _isLoading = true;
      _loadingText = "Analyzing meal with Gemini 2.5 Flash...";
      _errorMessage = null;
      if (type == 'image') {
        _selectedImageBase64 = optimizedContent;
      } else {
        _selectedImageBase64 = null;
      }
    });

    try {
      final result = await AIBackendService.analyzeMeal(
        type: type,
        content: optimizedContent,
      );

      if (result.containsKey('error')) {
        throw Exception(result['error']);
      }

      setState(() {
        _isLoading = false;
        final rawItems = result['items'] as List?;
        final parsedItems = rawItems != null
            ? rawItems.map((e) => BreakdownItem.fromJson(Map<String, dynamic>.from(e as Map))).toList()
            : <BreakdownItem>[];
        _selectedFood = StandardFood(
          foodName: result['foodName'] ?? 'Unknown Meal',
          calories: (result['calories'] ?? 0).toInt(),
          protein: (result['protein'] ?? 0).toInt(),
          carbs: (result['carbs'] ?? 0).toInt(),
          fat: (result['fat'] ?? 0).toInt(),
          servingSize: result['servingSize'] != null ? (result['servingSize'] as num).toDouble() : null,
          servingUnit: result['servingUnit']?.toString(),
          items: parsedItems,
        );
        _initializeReviewControllers();
        _showReview = true;
      });
    } catch (e) {
      final errStr = e.toString();
      setState(() {
        _isLoading = false;
        if (errStr.contains('UNAVAILABLE') ||
            errStr.contains('503') ||
            errStr.contains('high demand') ||
            errStr.contains('firebase_functions/internal')) {
          _errorMessage = "We're experiencing high demand right now. Please try again in a few moments.";
        } else {
          _errorMessage = "AI Analysis failed: ${e.toString()}";
        }
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
        final textColor = isDark ? Colors.white : AppTheme.textPrimary;
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
                      ? const Color(0xFF1C1E1B).withOpacity(0.95)
                      : Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF323530)
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
                          Text(
                            'Barcode Scanner Debug',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                              color: textColor,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppTheme.textPrimary;
    final borderColor = isDark ? const Color(0xFF323530) : AppTheme.glassBorder;

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
            color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.015),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: textColor,
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
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: 500,
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF0E0F0C)
                  : Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF323530)
                    : AppTheme.glassBorder,
                width: 1.0,
              ),
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
        const ZivoLoader(
          size: 60,
          strokeWidth: 4,
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
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => _showInstructionsBottomSheet(context, isDark),
                  child: const Icon(
                    Icons.question_mark_rounded,
                    color: AppTheme.accentCyan,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 8),
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
          ],
        ),
        const SizedBox(height: 20),

        // Custom Tab Bar styling
        Container(
          height: 58,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.03)
                : Colors.black.withOpacity(0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? const Color(0xFF323530)
                  : Colors.black.withOpacity(0.05),
            ),
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              color: AppTheme.accentCyan,
              borderRadius: BorderRadius.circular(12),
            ),
            labelColor: AppTheme.textPrimary,
            unselectedLabelColor: isDark ? const Color(0xFF868685) : AppTheme.textSecondary,
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelPadding: EdgeInsets.zero,
            tabs: const [
              Tab(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.camera_alt_rounded, size: 18),
                    SizedBox(height: 2),
                    Text("Photo", style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, letterSpacing: -0.2)),
                  ],
                ),
              ),
              Tab(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.qr_code_scanner_rounded, size: 18),
                    SizedBox(height: 2),
                    Text("Barcode", style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, letterSpacing: -0.2)),
                  ],
                ),
              ),
              Tab(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.mic_rounded, size: 18),
                    SizedBox(height: 2),
                    Text("Voice", style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, letterSpacing: -0.2)),
                  ],
                ),
              ),
              Tab(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.edit_note_rounded, size: 18),
                    SizedBox(height: 2),
                    Text("Describe", style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, letterSpacing: -0.2)),
                  ],
                ),
              ),
              Tab(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.post_add_rounded, size: 18),
                    SizedBox(height: 2),
                    Text("Manual", style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, letterSpacing: -0.2)),
                  ],
                ),
              ),
              Tab(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.bookmarks_rounded, size: 18),
                    SizedBox(height: 2),
                    Text("Presets", style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, letterSpacing: -0.2)),
                  ],
                ),
              ),
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
                  _buildPhotoFlow(isDark),
                  _buildBarcodeFlow(isDark),
                  _buildVoiceFlow(isDark),
                  _buildTextFlow(isDark),
                  _buildManualFlow(isDark),
                  _buildPresetsFlow(isDark),
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
    return SingleChildScrollView(
      child: Column(
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
                              const ZivoLoader(
                                size: 40,
                                strokeWidth: 3.5,
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
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isDark ? AppTheme.glassBorder : Colors.black.withOpacity(0.1),
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.photo_library_rounded, color: AppTheme.accentCyan, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        "Upload Image",
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white : AppTheme.textPrimary,
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
                    color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isDark ? AppTheme.glassBorder : Colors.black.withOpacity(0.1),
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.bug_report_rounded, color: AppTheme.accentCyan, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        "Test Asset",
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white : AppTheme.textPrimary,
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
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: isDark ? const Color(0xFF323530) : AppTheme.textPrimary),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: isDark ? const Color(0xFF323530) : AppTheme.textPrimary),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
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
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Center(
                  child: Icon(Icons.arrow_forward_rounded, color: Colors.black, size: 18),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}


  Widget _buildPhotoFlow(bool isDark) {
    return SingleChildScrollView(
      child: Column(
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
          SizedBox(
            height: 180,
            child: Row(
              children: [
                // Take Photo Card
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      ImagePickerHelper.pickImage((base64, name, filePath) {
                        setState(() {
                          _selectedImageBase64 = base64;
                        });
                        _runGeminiAnalysis('image', base64);
                      }, fromCamera: true);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.02)
                            : Colors.black.withOpacity(0.02),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF323530)
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
                              Icons.photo_camera_rounded,
                              color: AppTheme.accentCyan,
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "Take Photo",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isDark ? Colors.white : AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            "Use camera",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Upload Photo Card
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      ImagePickerHelper.pickImage((base64, name, filePath) {
                        setState(() {
                          _selectedImageBase64 = base64;
                        });
                        _runGeminiAnalysis('image', base64);
                      }, fromCamera: false);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.02)
                            : Colors.black.withOpacity(0.02),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF323530)
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
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "Upload Photo",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isDark ? Colors.white : AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            "From gallery",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 10,
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
        ],
      ),
    );
  }

  Widget _buildVoiceFlow(bool isDark) {
    return SingleChildScrollView(
      child: Column(
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
                borderRadius: BorderRadius.circular(24),
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
        const SizedBox(height: 20),
        GestureDetector(
          onTap: _voiceTranscript.isEmpty
              ? null
              : () => _runGeminiAnalysis('voice', _voiceTranscript),
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _voiceTranscript.isEmpty
                    ? (isDark ? AppTheme.glassBorder : Colors.black.withOpacity(0.1))
                    : AppTheme.accentCyan,
                width: 1.2,
              ),
            ),
            child: Center(
              child: Text(
                "Analyze Spoken Meal",
                style: TextStyle(
                  color: _voiceTranscript.isEmpty
                      ? AppTheme.textSecondary
                      : (isDark ? AppTheme.accentCyan : AppTheme.textPrimary),
                  fontSize: 15,
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

  Widget _buildTextFlow(bool isDark) {
    return SingleChildScrollView(
      child: Column(
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
          focusNode: _describeFocusNode,
          maxLines: 2,
          onChanged: (_) => setState(() {}),
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
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark
                    ? AppTheme.glassBorder
                    : AppTheme.textPrimary,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark
                    ? AppTheme.glassBorder
                    : AppTheme.textPrimary,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
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
                borderRadius: BorderRadius.circular(24),
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
        const SizedBox(height: 20),
        GestureDetector(
          onTap: _textDescriptionController.text.trim().isEmpty
              ? null
              : () => _runGeminiAnalysis('text', _textDescriptionController.text),
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _textDescriptionController.text.trim().isEmpty
                    ? (isDark ? AppTheme.glassBorder : Colors.black.withOpacity(0.1))
                    : AppTheme.accentCyan,
                width: 1.2,
              ),
            ),
            child: Center(
              child: Text(
                "Analyze Meal Description",
                style: TextStyle(
                  color: _textDescriptionController.text.trim().isEmpty
                      ? AppTheme.textSecondary
                      : (isDark ? AppTheme.accentCyan : AppTheme.textPrimary),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

  Widget _buildManualFlow(bool isDark) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "MANUAL ENTRY",
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),

          // Meal Name
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 6),
                child: Text(
                  "Meal Name",
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          TextField(
            controller: _manualNameController,
            focusNode: _manualFocusNode,
            style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w600, fontSize: 14),
            decoration: InputDecoration(
              hintText: "Meal Name (e.g. Rice and Chicken)...",
              hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 13),
              prefixIcon: const Icon(Icons.restaurant_menu_rounded, color: AppTheme.accentCyan, size: 20),
              filled: true,
              fillColor: isDark ? const Color(0xFF121214) : Colors.black.withOpacity(0.02),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: isDark ? const Color(0xFF2C2C2E) : AppTheme.glassBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: isDark ? const Color(0xFF2C2C2E) : AppTheme.glassBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.accentCyan, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Meal Breakdown Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text(
                    'MEAL BREAKDOWN',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (infoCtx) => Dialog(
                          backgroundColor: Colors.transparent,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: BackdropFilter(
                              filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                              child: Container(
                                constraints: const BoxConstraints(maxWidth: 360),
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF000000) : Colors.white.withOpacity(0.95),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF323530) : AppTheme.glassBorder,
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.question_mark_rounded, color: AppTheme.accentCyan, size: 24),
                                        const SizedBox(width: 8),
                                        Text(
                                          "Meal Breakdown Help",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                            color: isDark ? Colors.white : AppTheme.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      "Instead of guessing a meal's total calories, you can break it down into its separate ingredients (e.g., 'Chicken Biryani' into Rice, Chicken, Oil, etc.).\n\n"
                                      "The app automatically sums the nutrition of these items to calculate the total calories and macros for your food log.",
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDark ? Colors.white70 : AppTheme.textSecondary,
                                        height: 1.4,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                        onPressed: () => Navigator.pop(infoCtx),
                                        child: const Text("Got it", style: TextStyle(color: AppTheme.accentCyan, fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    child: Icon(Icons.question_mark_rounded, color: AppTheme.accentCyan, size: 14),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 20,
                    width: 35,
                    child: Transform.scale(
                      scale: 0.75,
                      child: Switch(
                        value: _showManualBreakdown,
                        activeColor: AppTheme.accentCyan,
                        onChanged: (val) {
                          setState(() {
                            _showManualBreakdown = val;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
              if (_showManualBreakdown)
                GestureDetector(
                  onTap: () => _showEditBreakdownItemDialog(null, null, isManual: true),
                  child: const Row(
                    children: [
                      Icon(Icons.add_circle_outline_rounded, color: AppTheme.accentCyan, size: 14),
                      SizedBox(width: 4),
                      Text(
                        "Add Item",
                        style: TextStyle(
                          color: AppTheme.accentCyan,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (_showManualBreakdown) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.01) : Colors.black.withOpacity(0.01),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppTheme.glassBorder : Colors.black.withOpacity(0.05),
                  width: 1.0,
                ),
              ),
            child: _manualBreakdownItems.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: Text(
                        "No breakdown items yet.\n\nExample: A 'Chicken Salad' meal can be broken down into 'Grilled Chicken (150g)', 'Lettuce (1 cup)', and 'Olive Oil (1 tbsp)' to calculate precise calories automatically.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  )
                : Column(
                    children: [
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _manualBreakdownItems.length,
                        separatorBuilder: (context, index) => Divider(
                          color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04),
                          height: 12,
                        ),
                        itemBuilder: (context, index) {
                          final item = _manualBreakdownItems[index];
                          return Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => _showEditBreakdownItemDialog(item, index, isManual: true),
                                  behavior: HitTestBehavior.opaque,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.name,
                                        style: TextStyle(
                                          color: isDark ? Colors.white : AppTheme.textPrimary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        "${item.servingSize % 1 == 0 ? item.servingSize.toInt().toString() : item.servingSize.toString()} ${item.servingUnit} • ${item.calories} kcal • P: ${item.protein}g C: ${item.carbs}g F: ${item.fat}g",
                                        style: const TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.accentCoral, size: 18),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () {
                                  setState(() {
                                    _manualBreakdownItems.removeAt(index);
                                  });
                                  _updateManualTotalsFromBreakdown();
                                },
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
          ),
        ],
        const SizedBox(height: 14),

          // Serving Size & Unit Row
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 6),
                      child: Text(
                        "Serving Size",
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    TextField(
                      controller: _manualServingSizeController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w600, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: "1.0",
                        hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 13),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF121214) : Colors.black.withOpacity(0.02),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: isDark ? const Color(0xFF2C2C2E) : AppTheme.glassBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: isDark ? const Color(0xFF2C2C2E) : AppTheme.glassBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTheme.accentCyan, width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 6),
                      child: Text(
                        "Serving Unit",
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      height: 52,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF121214) : Colors.black.withOpacity(0.02),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? const Color(0xFF2C2C2E) : AppTheme.glassBorder,
                          width: 1.0,
                        ),
                      ),
                      child: Center(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedServingUnit,
                            dropdownColor: isDark ? const Color(0xFF1C1E1B) : Colors.white,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.accentCyan),
                            isExpanded: true,
                            items: () {
                              final list = List<String>.from(_servingUnits);
                              if (!list.contains(_selectedServingUnit)) {
                                list.add(_selectedServingUnit);
                              }
                              return list.map((String unit) {
                                return DropdownMenuItem<String>(
                                  value: unit,
                                  child: Text(unit),
                                );
                              }).toList();
                            }(),
                            onChanged: (String? val) {
                              if (val != null) {
                                  setState(() {
                                    _selectedServingUnit = val;
                                  });
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Calories
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 6),
                child: Text(
                  "Calories",
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          TextField(
            controller: _manualCalController,
            keyboardType: TextInputType.number,
            style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w600, fontSize: 14),
            decoration: InputDecoration(
              hintText: "0",
              hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 13),
              prefixIcon: const Padding(
                padding: EdgeInsets.only(left: 12, right: 8),
                child: Center(
                  widthFactor: 1.0,
                  child: Text('🔥', style: TextStyle(fontSize: 20)),
                ),
              ),
              suffixIcon: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    "kcal",
                    style: TextStyle(color: isDark ? const Color(0xFF868685) : AppTheme.textSecondary, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
              filled: true,
              fillColor: isDark ? const Color(0xFF121214) : Colors.black.withOpacity(0.02),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: isDark ? const Color(0xFF2C2C2E) : AppTheme.glassBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: isDark ? const Color(0xFF2C2C2E) : AppTheme.glassBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.accentCyan, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Macronutrients Title
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              "MACRONUTRIENTS",
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.0),
            ),
          ),
          Row(
            children: [
              // Protein
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 6),
                      child: Text(
                        "Protein",
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    TextField(
                      controller: _manualProteinController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w600, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: "0",
                        hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 12),
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(left: 10, right: 6),
                          child: Center(
                            widthFactor: 1.0,
                            child: Text('🍗', style: TextStyle(fontSize: 16)),
                          ),
                        ),
                        suffixIcon: Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Center(
                            widthFactor: 1,
                            child: Text(
                              "g",
                              style: TextStyle(color: isDark ? const Color(0xFF868685) : AppTheme.textSecondary, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF121214) : Colors.black.withOpacity(0.02),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: isDark ? const Color(0xFF2C2C2E) : AppTheme.glassBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: isDark ? const Color(0xFF2C2C2E) : AppTheme.glassBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTheme.accentCyan, width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Carbs
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 6),
                      child: Text(
                        "Carbs",
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    TextField(
                      controller: _manualCarbsController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w600, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: "0",
                        hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 12),
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(left: 10, right: 6),
                          child: Center(
                            widthFactor: 1.0,
                            child: Text('🍚', style: TextStyle(fontSize: 16)),
                          ),
                        ),
                        suffixIcon: Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Center(
                            widthFactor: 1,
                            child: Text(
                              "g",
                              style: TextStyle(color: isDark ? const Color(0xFF868685) : AppTheme.textSecondary, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF121214) : Colors.black.withOpacity(0.02),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: isDark ? const Color(0xFF2C2C2E) : AppTheme.glassBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: isDark ? const Color(0xFF2C2C2E) : AppTheme.glassBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTheme.accentCyan, width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Fat
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 6),
                      child: Text(
                        "Fat",
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    TextField(
                      controller: _manualFatController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w600, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: "0",
                        hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 12),
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(left: 10, right: 6),
                          child: Center(
                            widthFactor: 1.0,
                            child: Text('🥑', style: TextStyle(fontSize: 16)),
                          ),
                        ),
                        suffixIcon: Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Center(
                            widthFactor: 1,
                            child: Text(
                              "g",
                              style: TextStyle(color: isDark ? const Color(0xFF868685) : AppTheme.textSecondary, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF121214) : Colors.black.withOpacity(0.02),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: isDark ? const Color(0xFF2C2C2E) : AppTheme.glassBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: isDark ? const Color(0xFF2C2C2E) : AppTheme.glassBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTheme.accentCyan, width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildCategorySelector(isDark),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    final String name = _manualNameController.text.trim().isNotEmpty ? _manualNameController.text.trim() : "Manual Meal";
                    final String sizeText = _manualServingSizeController.text.trim();
                    final String finalName = sizeText.isNotEmpty 
                        ? "$name ($sizeText $_selectedServingUnit)"
                        : name;

                    await StorageService.saveFoodPreset({
                      'name': finalName,
                      'calories': int.tryParse(_manualCalController.text) ?? 0,
                      'protein': int.tryParse(_manualProteinController.text) ?? 0,
                      'carbs': int.tryParse(_manualCarbsController.text) ?? 0,
                      'fat': int.tryParse(_manualFatController.text) ?? 0,
                      'items': _manualBreakdownItems.map((e) => e.toJson()).toList(),
                    });
                    FirebaseService.saveFoodPresetsCloud(StorageService.getFoodPresets());

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: AppTheme.accentEmerald,
                        content: Text("Preset '$finalName' saved successfully!"),
                      ),
                    );
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 52,
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppTheme.accentCyan.withOpacity(0.06)
                          : Colors.black.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(
                        color: AppTheme.accentCyan.withOpacity(0.4),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bookmark_add_rounded, color: isDark ? AppTheme.accentCyan : AppTheme.textPrimary, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          "Save Preset",
                          style: TextStyle(
                            color: isDark ? AppTheme.accentCyan : AppTheme.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    // Sync totals from breakdown items if present before saving
                    if (_manualBreakdownItems.isNotEmpty) {
                      int totalCals = 0;
                      int totalProtein = 0;
                      int totalCarbs = 0;
                      int totalFat = 0;
                      for (final item in _manualBreakdownItems) {
                        totalCals += item.calories;
                        totalProtein += item.protein;
                        totalCarbs += item.carbs;
                        totalFat += item.fat;
                      }
                      _manualCalController.text = totalCals.toString();
                      _manualProteinController.text = totalProtein.toString();
                      _manualCarbsController.text = totalCarbs.toString();
                      _manualFatController.text = totalFat.toString();
                    }

                    final String name = _manualNameController.text.trim().isNotEmpty ? _manualNameController.text.trim() : "Manual Meal";
                    final int cal = int.tryParse(_manualCalController.text) ?? 0;
                    final int prot = int.tryParse(_manualProteinController.text) ?? 0;
                    final int carb = int.tryParse(_manualCarbsController.text) ?? 0;
                    final int fat = int.tryParse(_manualFatController.text) ?? 0;
                    
                    final String sizeText = _manualServingSizeController.text.trim();
                    final String finalName = sizeText.isNotEmpty 
                        ? "$name ($sizeText $_selectedServingUnit)"
                        : name;

                    final selectedDate = ref.read(selectedDateProvider);
                    ref.read(dailyMetricsProvider(selectedDate).notifier).logMeal(
                          mealKey: _selectedMealKey,
                          calories: cal,
                          protein: prot,
                          carbs: carb,
                          fat: fat,
                          foodName: finalName,
                          breakdownItems: _manualBreakdownItems.map((e) => e.toJson()).toList(),
                        );

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: AppTheme.accentEmerald,
                        content: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Colors.black),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "Successfully Logged: $finalName!",
                                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );

                    _manualNameController.clear();
                    _manualCalController.clear();
                    _manualProteinController.clear();
                    _manualCarbsController.clear();
                    _manualFatController.clear();
                    _manualServingSizeController.text = "1";
                    _selectedServingUnit = 'serving';
                    _showManualBreakdown = false;
                    _manualBreakdownItems.clear();

                    Navigator.of(context).pop();
                  },
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppTheme.accentCyan,
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accentCyan.withOpacity(0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        "Log Meal",
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
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
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedMealKey = cat['key'] as String;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.accentCyan
                          : (isDark
                              ? Colors.white.withOpacity(0.03)
                              : Colors.black.withOpacity(0.03)),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.accentCyan
                            : (isDark
                                ? AppTheme.glassBorder
                                : Colors.black.withOpacity(0.08)),
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
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
                  ),
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
                  Text(
                    'Review Screen',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      color: isDark ? Colors.white : AppTheme.textPrimary,
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF121214) : const Color(0xFFE2F6D5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFC5EDAB),
                width: 1.0,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.accentCyan.withOpacity(0.12) : const Color(0xFFC5EDAB),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: isDark ? AppTheme.accentCyan : const Color(0xFF054D28),
                    size: 14,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "AI ESTIMATE NOTICE",
                        style: TextStyle(
                          color: isDark ? AppTheme.accentCyan : const Color(0xFF054D28),
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        "Nutritional values are estimates generated by AI. Please review and adjust the details below.",
                        style: TextStyle(
                          color: isDark ? const Color(0xFF868685) : const Color(0xFF0E0F0C),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    ],
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
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark
                      ? AppTheme.glassBorder
                      : AppTheme.textPrimary,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark
                      ? AppTheme.glassBorder
                      : AppTheme.textPrimary,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.accentCyan),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Meal Breakdown Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text(
                    'MEAL BREAKDOWN',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (infoCtx) => AlertDialog(
                          backgroundColor: isDark ? const Color(0xFF1C1E1B) : Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          title: const Text("Meal Breakdown Help", style: TextStyle(fontWeight: FontWeight.bold)),
                          content: const Text(
                            "Instead of guessing a meal's total calories, you can break it down into its separate ingredients (e.g., 'Chicken Biryani' into Rice, Chicken, Oil, etc.).\n\n"
                            "The app automatically sums the nutrition of these items to calculate the total calories and macros for your food log."
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(infoCtx),
                              child: const Text("Got it", style: TextStyle(color: AppTheme.accentCyan)),
                            )
                          ],
                        ),
                      );
                    },
                    child: Icon(Icons.help_outline_rounded, color: isDark ? Colors.white60 : Colors.black54, size: 14),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 20,
                    width: 35,
                    child: Transform.scale(
                      scale: 0.75,
                      child: Switch(
                        value: _showReviewBreakdown,
                        activeColor: AppTheme.accentCyan,
                        onChanged: (val) {
                          setState(() {
                            _showReviewBreakdown = val;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
              if (_showReviewBreakdown)
                GestureDetector(
                  onTap: () => _showEditBreakdownItemDialog(null, null),
                  child: const Row(
                    children: [
                      Icon(Icons.add_circle_outline_rounded, color: AppTheme.accentCyan, size: 14),
                      SizedBox(width: 4),
                      Text(
                        "Add Item",
                        style: TextStyle(
                          color: AppTheme.accentCyan,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (_showReviewBreakdown) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.01) : Colors.black.withOpacity(0.01),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppTheme.glassBorder : Colors.black.withOpacity(0.05),
                  width: 1.0,
                ),
              ),
            child: _reviewBreakdownItems.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: Text(
                        "No breakdown items yet.\n\nExample: A 'Chicken Salad' meal can be broken down into 'Grilled Chicken (150g)', 'Lettuce (1 cup)', and 'Olive Oil (1 tbsp)' to calculate precise calories automatically.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  )
                : Column(
                    children: [
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _reviewBreakdownItems.length,
                        separatorBuilder: (context, index) => Divider(
                          color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04),
                          height: 12,
                        ),
                        itemBuilder: (context, index) {
                          final item = _reviewBreakdownItems[index];
                          return Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => _showEditBreakdownItemDialog(item, index),
                                  behavior: HitTestBehavior.opaque,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.name,
                                        style: TextStyle(
                                          color: isDark ? Colors.white : AppTheme.textPrimary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        "${item.servingSize % 1 == 0 ? item.servingSize.toInt().toString() : item.servingSize.toString()} ${item.servingUnit} • ${item.calories} kcal • P: ${item.protein}g C: ${item.carbs}g F: ${item.fat}g",
                                        style: const TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.accentCoral, size: 18),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () {
                                  setState(() {
                                    _reviewBreakdownItems.removeAt(index);
                                  });
                                  _updateTotalsFromBreakdown();
                                },
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
          ),
        ],
        const SizedBox(height: 14),

          // Serving Size & Unit Row
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 6),
                      child: Text(
                        "Serving Size",
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    TextField(
                      controller: _reviewServingSizeController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w600, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: "1.0",
                        hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 13),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF121214) : Colors.black.withOpacity(0.02),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: isDark ? const Color(0xFF2C2C2E) : AppTheme.glassBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: isDark ? const Color(0xFF2C2C2E) : AppTheme.glassBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTheme.accentCyan, width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 6),
                      child: Text(
                        "Serving Unit",
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      height: 52,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF121214) : Colors.black.withOpacity(0.02),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? const Color(0xFF2C2C2E) : AppTheme.glassBorder,
                          width: 1.0,
                        ),
                      ),
                      child: Center(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _reviewSelectedServingUnit,
                            dropdownColor: isDark ? const Color(0xFF1C1E1B) : Colors.white,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.accentCyan),
                            isExpanded: true,
                            items: () {
                              final list = List<String>.from(_servingUnits);
                              if (!list.contains(_reviewSelectedServingUnit)) {
                                list.add(_reviewSelectedServingUnit);
                              }
                              return list.map((String unit) {
                                return DropdownMenuItem<String>(
                                  value: unit,
                                  child: Text(unit),
                                );
                              }).toList();
                            }(),
                            onChanged: (String? val) {
                              if (val != null) {
                                setState(() {
                                  _reviewSelectedServingUnit = val;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
          // Calories
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 6),
                child: Text(
                  "Calories",
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          TextField(
            controller: _reviewCalController,
            keyboardType: TextInputType.number,
            style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w600, fontSize: 14),
            decoration: InputDecoration(
              hintText: "0",
              hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 13),
              prefixIcon: const Padding(
                padding: EdgeInsets.only(left: 12, right: 8),
                child: Center(
                  widthFactor: 1.0,
                  child: Text('🔥', style: TextStyle(fontSize: 20)),
                ),
              ),
              suffixIcon: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    "kcal",
                    style: TextStyle(color: isDark ? const Color(0xFF868685) : AppTheme.textSecondary, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
              filled: true,
              fillColor: isDark ? const Color(0xFF121214) : Colors.black.withOpacity(0.02),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: isDark ? const Color(0xFF2C2C2E) : AppTheme.glassBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: isDark ? const Color(0xFF2C2C2E) : AppTheme.glassBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.accentCyan, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Macronutrients Title
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              "MACRONUTRIENTS",
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.0),
            ),
          ),
          Row(
            children: [
              // Protein
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 6),
                      child: Text(
                        "Protein",
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    TextField(
                      controller: _reviewProteinController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w600, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: "0",
                        hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 12),
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(left: 10, right: 6),
                          child: Center(
                            widthFactor: 1.0,
                            child: Text('🍗', style: TextStyle(fontSize: 16)),
                          ),
                        ),
                        suffixIcon: Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Center(
                            widthFactor: 1,
                            child: Text(
                              "g",
                              style: TextStyle(color: isDark ? const Color(0xFF868685) : AppTheme.textSecondary, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF121214) : Colors.black.withOpacity(0.02),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: isDark ? const Color(0xFF2C2C2E) : AppTheme.glassBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: isDark ? const Color(0xFF2C2C2E) : AppTheme.glassBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTheme.accentCyan, width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Carbs
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 6),
                      child: Text(
                        "Carbs",
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    TextField(
                      controller: _reviewCarbsController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w600, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: "0",
                        hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 12),
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(left: 10, right: 6),
                          child: Center(
                            widthFactor: 1.0,
                            child: Text('🍚', style: TextStyle(fontSize: 16)),
                          ),
                        ),
                        suffixIcon: Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Center(
                            widthFactor: 1,
                            child: Text(
                              "g",
                              style: TextStyle(color: isDark ? const Color(0xFF868685) : AppTheme.textSecondary, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF121214) : Colors.black.withOpacity(0.02),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: isDark ? const Color(0xFF2C2C2E) : AppTheme.glassBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: isDark ? const Color(0xFF2C2C2E) : AppTheme.glassBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTheme.accentCyan, width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Fat
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 6),
                      child: Text(
                        "Fat",
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    TextField(
                      controller: _reviewFatController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w600, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: "0",
                        hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 12),
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(left: 10, right: 6),
                          child: Center(
                            widthFactor: 1.0,
                            child: Text('🥑', style: TextStyle(fontSize: 16)),
                          ),
                        ),
                        suffixIcon: Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Center(
                            widthFactor: 1,
                            child: Text(
                              "g",
                              style: TextStyle(color: isDark ? const Color(0xFF868685) : AppTheme.textSecondary, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF121214) : Colors.black.withOpacity(0.02),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: isDark ? const Color(0xFF2C2C2E) : AppTheme.glassBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: isDark ? const Color(0xFF2C2C2E) : AppTheme.glassBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTheme.accentCyan, width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildCategorySelector(isDark),
          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    final String name = _reviewNameController.text.trim().isNotEmpty
                        ? _reviewNameController.text.trim()
                        : "Unknown Meal";
                    final String sizeText = _reviewServingSizeController.text.trim();
                    final String finalName = sizeText.isNotEmpty
                        ? "$name ($sizeText $_reviewSelectedServingUnit)"
                        : name;

                    await StorageService.saveFoodPreset({
                      'name': finalName,
                      'calories': int.tryParse(_reviewCalController.text) ?? 0,
                      'protein': int.tryParse(_reviewProteinController.text) ?? 0,
                      'carbs': int.tryParse(_reviewCarbsController.text) ?? 0,
                      'fat': int.tryParse(_reviewFatController.text) ?? 0,
                    });
                    FirebaseService.saveFoodPresetsCloud(StorageService.getFoodPresets());

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: AppTheme.accentEmerald,
                        content: Text("Preset '$finalName' saved successfully!"),
                      ),
                    );
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 52,
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppTheme.accentCyan.withOpacity(0.06)
                          : Colors.black.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(
                        color: AppTheme.accentCyan.withOpacity(0.4),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bookmark_add_rounded, color: isDark ? AppTheme.accentCyan : AppTheme.textPrimary, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          "Save Preset",
                          style: TextStyle(
                            color: isDark ? AppTheme.accentCyan : AppTheme.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    // Sync totals from breakdown items if present before saving
                    if (_reviewBreakdownItems.isNotEmpty) {
                      int totalCals = 0;
                      int totalProtein = 0;
                      int totalCarbs = 0;
                      int totalFat = 0;
                      for (final item in _reviewBreakdownItems) {
                        totalCals += item.calories;
                        totalProtein += item.protein;
                        totalCarbs += item.carbs;
                        totalFat += item.fat;
                      }
                      _reviewCalController.text = totalCals.toString();
                      _reviewProteinController.text = totalProtein.toString();
                      _reviewCarbsController.text = totalCarbs.toString();
                      _reviewFatController.text = totalFat.toString();
                    }

                    // Assemble the updated Standard Food Object from review TextFields
                    final String name = _reviewNameController.text.trim().isNotEmpty
                        ? _reviewNameController.text.trim()
                        : "Unknown Meal";
                    final String sizeText = _reviewServingSizeController.text.trim();
                    final String finalName = sizeText.isNotEmpty
                        ? "$name ($sizeText $_reviewSelectedServingUnit)"
                        : name;

                    final finalFood = StandardFood(
                      foodName: finalName,
                      calories: int.tryParse(_reviewCalController.text) ?? 0,
                      protein: int.tryParse(_reviewProteinController.text) ?? 0,
                      carbs: int.tryParse(_reviewCarbsController.text) ?? 0,
                      fat: int.tryParse(_reviewFatController.text) ?? 0,
                      servingSize: double.tryParse(sizeText),
                      servingUnit: _reviewSelectedServingUnit,
                      items: _reviewBreakdownItems,
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
                          breakdownItems: finalFood.items.map((e) => e.toJson()).toList(),
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
                      color: AppTheme.accentCyan,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Center(
                      child: Text(
                        "Done",
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPresetsFlow(bool isDark) {
    final presets = StorageService.getFoodPresets();
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "SAVED MEAL PRESETS",
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          if (presets.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40.0),
                child: Column(
                  children: [
                    Icon(Icons.bookmark_border_rounded, size: 48, color: AppTheme.textSecondary.withOpacity(0.3)),
                    const SizedBox(height: 12),
                    const Text(
                      "No presets saved yet.",
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "Save any logged meal as a preset\nto log it instantly next time.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: presets.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final preset = presets[index];
                final String name = preset['name'] ?? 'Unnamed Preset';
                final int cal = preset['calories'] ?? 0;
                final int prot = preset['protein'] ?? 0;
                final int carb = preset['carbs'] ?? 0;
                final int fat = preset['fat'] ?? 0;

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF121214) : Colors.black.withOpacity(0.02),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? const Color(0xFF2C2C2E) : AppTheme.glassBorder,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Preset Info
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            // Populate manual entry controllers
                            setState(() {
                              _manualNameController.text = name;
                              _manualCalController.text = cal.toString();
                              _manualProteinController.text = prot.toString();
                              _manualCarbsController.text = carb.toString();
                              _manualFatController.text = fat.toString();
                              _tabController.index = 4; // Switch to Manual tab
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                duration: Duration(seconds: 2),
                                content: Text("Loaded preset details into Manual Entry!"),
                              ),
                            );
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: TextStyle(
                                  color: isDark ? Colors.white : AppTheme.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "🔥 $cal kcal  |  🍗 ${prot}g  |  🍚 ${carb}g  |  🥑 ${fat}g",
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Action buttons
                      Row(
                        children: [
                          // Quick Log Button
                          IconButton(
                            icon: const Icon(Icons.add_circle_rounded, color: AppTheme.accentCyan, size: 26),
                            tooltip: "Quick Log Meal",
                            onPressed: () {
                              final selectedDate = ref.read(selectedDateProvider);
                              ref.read(dailyMetricsProvider(selectedDate).notifier).logMeal(
                                    mealKey: _selectedMealKey,
                                    calories: cal,
                                    protein: prot,
                                    carbs: carb,
                                    fat: fat,
                                    foodName: name,
                                  );

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: AppTheme.accentEmerald,
                                  content: Text(
                                    "Logged: $name to ${(_selectedMealKey.replaceAll('_cal', '').replaceAll('_', ' ').toUpperCase())}!",
                                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              );
                              Navigator.of(context).pop();
                            },
                          ),
                          // Edit Button
                          IconButton(
                            icon: const Icon(Icons.edit_rounded, color: AppTheme.accentCyan, size: 20),
                            tooltip: "Edit Preset",
                            onPressed: () {
                              _showEditPresetDialog(preset);
                            },
                          ),
                          // Delete Button
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.accentCoral, size: 20),
                            tooltip: "Delete Preset",
                            onPressed: () async {
                              await StorageService.deleteFoodPreset(name);
                              FirebaseService.saveFoodPresetsCloud(StorageService.getFoodPresets());
                              setState(() {}); // refresh list
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

