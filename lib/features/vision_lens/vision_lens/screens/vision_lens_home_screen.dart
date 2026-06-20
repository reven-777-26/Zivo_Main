import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme.dart';
import '../../../../services/state_providers.dart';
import '../../../../services/scanner/camera_barcode_scanner.dart';
import '../../../../services/scanner/native_barcode_scanner.dart';
import '../../../../utils/image_picker_helper.dart';
import '../../../../utils/web_barcode_scanner.dart';
import '../../shared/providers/unified_vision_provider.dart';
import 'unified_product_detail_screen.dart';
import '../../../dashboard/food_logger_dialog.dart';
import '../../../dashboard/food_history_screen.dart';
import '../../../../core/widgets/zivo_loader.dart';
import 'zivo_analyzer_loading_widget.dart';
import '../../../../services/audio_service.dart';


class VisionLensHomeScreen extends ConsumerStatefulWidget {
  const VisionLensHomeScreen({super.key});

  @override
  ConsumerState<VisionLensHomeScreen> createState() => _VisionLensHomeScreenState();
}

class _VisionLensHomeScreenState extends ConsumerState<VisionLensHomeScreen> with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  bool _isProcessingFrame = false;
  bool _isInitializing = false;
  Timer? _webFrameTimer;
  String? _errorMessage;
  int _activeSectionTab = 0; // 0: Food Log, 1: Zivo Analyser

  final TextEditingController _barcodeInputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Initialize history
    Future.microtask(() => ref.read(unifiedVisionProvider.notifier).loadHistory());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void didUpdateWidget(covariant VisionLensHomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeCamera();
    _barcodeInputController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _disposeCamera();
    } else if (state == AppLifecycleState.resumed) {
      final activeTab = ref.read(activeTabProvider);
      final isCurrentRoute = ModalRoute.of(context)?.isCurrent ?? true;
      if (activeTab == 2 && isCurrentRoute) {
        _initializeCamera();
      }
    }
  }

  void _checkCameraLifecycle(int activeTab, bool isCurrentRoute) {
    if (activeTab == 2 && isCurrentRoute && _activeSectionTab == 1) {
      if (!_isCameraInitialized && _cameraController == null) {
        _initializeCamera();
      }
    } else {
      if (_isCameraInitialized || _cameraController != null) {
        _disposeCamera();
      }
    }
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
            _errorMessage = "No camera found. Upload a product photo instead.";
          });
        }
      }
    } catch (e) {
      debugPrint("Vision camera initialization failed: $e");
      if (mounted) {
        setState(() {
          _errorMessage = "Camera not available. Upload a product photo instead.";
        });
      }
    } finally {
      _isInitializing = false;
    }
  }

  void _startBarcodeScanningLoop() {
    if (_cameraController == null || !_isCameraInitialized) return;

    if (kIsWeb) {
      _webFrameTimer = Timer.periodic(const Duration(milliseconds: 700), (timer) async {
        final state = ref.read(unifiedVisionProvider);
        if (state.isScanning || _isProcessingFrame || !mounted || _cameraController == null || !_isCameraInitialized || !_cameraController!.value.isInitialized) return;
        _isProcessingFrame = true;
        try {
          final XFile file = await _cameraController!.takePicture();
          if (!mounted || _cameraController == null || !_isCameraInitialized) {
            _isProcessingFrame = false;
            return;
          }
          final bytes = await file.readAsBytes();
          
          // 1. Try Browser's Native BarcodeDetector API first (high performance)
          final base64String = 'data:image/jpeg;base64,${base64Encode(bytes)}';
          final barcode = await scanBarcodeWebPlatform(base64String);
          if (barcode != null && barcode.isNotEmpty && mounted) {
            _isProcessingFrame = true;
            await _handleBarcodeScan(barcode);
            _isProcessingFrame = false;
            return;
          }

          // 2. Fallback to optimized pure-Dart ZXing reader
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
            final fallbackBarcode = await CameraBarcodeScanner.detectBarcode(frame);
            if (fallbackBarcode != null && fallbackBarcode.isNotEmpty && mounted) {
              _isProcessingFrame = true;
              await _handleBarcodeScan(fallbackBarcode);
              _isProcessingFrame = false;
            }
          }
        } catch (e) {
          if (_cameraController != null && _isCameraInitialized) {
            debugPrint("Web barcode scan frame error: $e");
          }
        } finally {
          _isProcessingFrame = false;
        }
      });
    } else {
      _cameraController!.startImageStream((CameraImage image) async {
        final state = ref.read(unifiedVisionProvider);
        if (state.isScanning || _isProcessingFrame || !mounted) return;
        _isProcessingFrame = true;
        try {
          final barcode = await NativeBarcodeScanner.scanCameraImage(image, _cameraController!.description);
          if (barcode != null && barcode.isNotEmpty && mounted) {
            _isProcessingFrame = true;
            await _handleBarcodeScan(barcode);
            _isProcessingFrame = false;
          }
        } catch (e) {
          debugPrint("Mobile barcode scan frame error: $e");
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
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _handleBarcodeScan(String barcode) async {
    if (barcode.trim().isEmpty) return;
    _showLoadingOverlay();
    
    await ref.read(unifiedVisionProvider.notifier).scanBarcodeAndAnalyze(
      barcode: barcode,
    );

    _dismissLoadingAndNavigate(barcode);
  }

  void _triggerTakeProductPhoto() {
    ImagePickerHelper.pickImage(
      (base64, name, filePath) async {
        _showLoadingOverlay();
        await ref.read(unifiedVisionProvider.notifier).analyzeFromImage(
          base64Content: base64,
          fileName: name,
        );

        if (!mounted) return;
        final state = ref.read(unifiedVisionProvider);
        final barcodeToUse = state.currentReport.value?.barcode ?? 'unknown';
        _dismissLoadingAndNavigate(barcodeToUse);
      },
      isBarcode: true,
      fromCamera: true,
    );
  }

  void _triggerImageScan() {
    ImagePickerHelper.pickImage(
      (base64, name, filePath) async {
        _showLoadingOverlay();
        await ref.read(unifiedVisionProvider.notifier).analyzeFromImage(
          base64Content: base64,
          fileName: name,
        );

        if (!mounted) return;
        final state = ref.read(unifiedVisionProvider);
        final barcodeToUse = state.currentReport.value?.barcode ?? 'unknown';
        _dismissLoadingAndNavigate(barcodeToUse);
      },
      isBarcode: true,
      fromCamera: false,
    );
  }

  void _triggerIngredientsScan() {
    ImagePickerHelper.pickImage(
      (base64, name, filePath) async {
        _showLoadingOverlay();
        await ref.read(unifiedVisionProvider.notifier).analyzeFromImage(
          base64Content: base64,
          fileName: name,
          isIngredientLabel: true,
        );

        if (!mounted) return;
        final state = ref.read(unifiedVisionProvider);
        final barcodeToUse = state.currentReport.value?.barcode ?? 'unknown';
        _dismissLoadingAndNavigate(barcodeToUse);
      },
      isBarcode: true,
      fromCamera: false,
    );
  }


  void _showLoadingOverlay() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, child) {
            final state = ref.watch(unifiedVisionProvider);
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return WillPopScope(
              onWillPop: () async => false,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(32),
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1C1E1B) : AppTheme.glassBackground,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isDark ? const Color(0xFF323530) : AppTheme.glassBorder,
                      width: 1.0,
                    ),
                  ),
                  child: ZivoAnalyzerLoadingWidget(
                    progressMessage: state.progressMessage,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _dismissLoadingAndNavigate(String barcode) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context); // close loader dialog
    }
    
    final state = ref.read(unifiedVisionProvider);
    state.currentReport.when(
      data: (report) {
        if (report != null) {
          AudioService.playAiOutput();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UnifiedProductDetailScreen(barcode: barcode),
            ),
          );
        }
      },
      loading: () {},
      error: (error, _) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString()),
            backgroundColor: AppTheme.accentCoral,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : AppTheme.textPrimary;
    final visionState = ref.watch(unifiedVisionProvider);

    final activeTab = ref.watch(activeTabProvider);
    final isCurrentRoute = ModalRoute.of(context)?.isCurrent ?? true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _checkCameraLifecycle(activeTab, isCurrentRoute);
      }
    });

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : AppTheme.textPrimary),
          onPressed: () => ref.read(activeTabProvider.notifier).state = 0,
        ),
        title: null,
        actions: [
          Center(
            child: GestureDetector(
              onTap: () => _showAnalyserHelpSheet(context),
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: const Color(0xFFD9FF00).withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFD9FF00),
                    width: 1.0,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.question_mark_rounded,
                    color: Color(0xFFD9FF00),
                    size: 12,
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.history_rounded, color: isDark ? Colors.white : AppTheme.textPrimary),
            onPressed: () {
              ref.read(unifiedVisionProvider.notifier).loadHistory();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('History reloaded.')),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              // Highlighted Premium Segmented Tab Selector
              Container(
                height: 48,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF121214) : const Color(0xFFE8EBE6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? const Color(0xFF2C2C2E) : Colors.black.withOpacity(0.06),
                    width: 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    _buildAppleTabItem('Food Log', 0),
                    _buildAppleTabItem('Zivo Analyser', 1),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _activeSectionTab == 0
                    ? _buildFoodLogPanel()
                    : _buildZivoAnalyserPanel(isDark, primaryTextColor, visionState),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildZivoAnalyserPanel(bool isDark, Color primaryTextColor, dynamic visionState) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Auto-detect notice (replaces manual category tabs)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.accentCyan.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.accentCyan.withOpacity(0.15),
                width: 1.0,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Zivo can analyzes your meals, food, supplements, and skincare products.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Live Camera Scanner Preview Card
          Container(
            height: 240,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _isCameraInitialized
                    ? AppTheme.accentCyan
                    : (isDark ? const Color(0xFF323530) : AppTheme.glassBorder),
                width: 1.0,
              ),
            ),
            clipBehavior: Clip.antiAlias,
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
                  Positioned.fill(
                    child: Container(
                      color: Colors.white.withOpacity(0.015),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.videocam_off_rounded,
                            size: 40,
                            color: _errorMessage != null ? AppTheme.accentCoral : AppTheme.textSecondary.withOpacity(0.4),
                          ),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24.0),
                            child: Text(
                              _errorMessage ?? 'Initializing barcode scanner...',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _errorMessage != null ? AppTheme.accentCoral : AppTheme.textSecondary,
                                fontSize: 12,
                                fontWeight: _errorMessage != null ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Guidelines Overlay
                if (_isCameraInitialized)
                  Container(
                    width: 240,
                    height: 110,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isDark ? AppTheme.accentCyan : const Color(0xFF054D28),
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),

                // Sweeping laser animation
                if (_isCameraInitialized)
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(seconds: 2),
                    builder: (context, value, child) {
                      return Positioned(
                        top: 60 + (value * 120),
                        left: 40,
                        right: 40,
                        child: Container(
                          height: 2,
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.accentCyan : const Color(0xFF054D28),
                          ),
                        ),
                      );
                    },
                  ),

                // Small instruction tag
                Positioned(
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      "Align EAN Barcode inside framework",
                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Actions Row (Take Photo, Upload Photo, Ingredients)
          Row(
            children: [
              Expanded(
                child: _buildActionBtn(
                  icon: Icons.camera_alt_rounded,
                  label: 'Take Photo',
                  color: AppTheme.accentCyan,
                  onTap: _triggerTakeProductPhoto,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionBtn(
                  icon: Icons.photo_library_rounded,
                  label: 'Upload Photo',
                  color: AppTheme.accentCyan,
                  onTap: _triggerImageScan,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionBtn(
                  icon: Icons.receipt_long_rounded,
                  label: 'Ingredients',
                  color: AppTheme.accentCyan,
                  onTap: _triggerIngredientsScan,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Manual lookup row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1E1B) : AppTheme.glassBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xFF323530) : AppTheme.textPrimary,
                width: 1.0,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _barcodeInputController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: primaryTextColor, fontSize: 13, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'Or type barcode digits manually...',
                      hintStyle: TextStyle(
                        color: isDark ? const Color(0xFF868685) : AppTheme.textSecondary,
                        fontSize: 11,
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    final code = _barcodeInputController.text.trim();
                    if (code.isNotEmpty) {
                      _barcodeInputController.clear();
                      _handleBarcodeScan(code);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.accentCyan,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(Icons.arrow_forward_rounded, color: AppTheme.textPrimary, size: 18),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Unified Recent Scans list header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'RECENT PRODUCT SCANS',
                style: TextStyle(
                  color: isDark ? const Color(0xFF868685) : AppTheme.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
              if (visionState.history.isNotEmpty)
                GestureDetector(
                  onTap: () => ref.read(unifiedVisionProvider.notifier).clearHistory(),
                  child: const Text(
                    'Clear History',
                    style: TextStyle(color: AppTheme.accentCoral, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Unified Scans List
          if (visionState.history.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C1E1B) : AppTheme.glassBackground,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark ? const Color(0xFF323530) : AppTheme.glassBorder,
                  width: 1.0,
                ),
              ),
              child: Column(
                children: [
                  Icon(Icons.center_focus_weak_rounded, color: AppTheme.textSecondary.withOpacity(0.3), size: 36),
                  const SizedBox(height: 10),
                  Text(
                    'No Scan History',
                    style: TextStyle(
                      color: isDark ? Colors.white : AppTheme.textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Scan a barcode or upload a product photo to get started.',
                    style: TextStyle(
                      color: isDark ? const Color(0xFF868685) : AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: visionState.history.length,
              itemBuilder: (context, idx) {
                final item = visionState.history[idx];
                final scoreColor = _getGradeColor(item.healthGrade, isDark);
                final categoryIcon = item.category.toLowerCase() == 'skincare'
                    ? '🧴'
                    : (item.category.toLowerCase() == 'supplement' ? '💊' : '🍔');

                final cardBgColor = isDark ? const Color(0xFF121214) : AppTheme.glassBackground;
                final borderColor = isDark ? const Color(0xFF2C2C2E) : AppTheme.glassBorder;
                final textColor = isDark ? Colors.white : AppTheme.textPrimary;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: GestureDetector(
                    onTap: () {
                      ref.read(unifiedVisionProvider.notifier).resetCurrentReport();
                      ref.read(unifiedVisionProvider.notifier).scanBarcodeAndAnalyze(barcode: item.barcode);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => UnifiedProductDetailScreen(barcode: item.barcode),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardBgColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: borderColor, width: 1.0),
                      ),
                      child: Row(
                        children: [
                          // Circular Grade Avatar
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: scoreColor.withOpacity(0.08),
                              border: Border.all(color: scoreColor.withOpacity(0.3), width: 1.0),
                            ),
                            child: Center(
                              child: Text(
                                item.healthGrade,
                                style: TextStyle(
                                  color: scoreColor,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 22,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),

                          // Title / Details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.productName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE8EBE6),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isDark ? const Color(0xFF3A3A3C) : AppTheme.glassBorder,
                                      width: 1.0,
                                    ),
                                  ),
                                  child: Text(
                                    '$categoryIcon ${item.brand} • ${item.category.toUpperCase()}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                      color: isDark ? Colors.white : AppTheme.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),

                          // Trailing Chevron
                          Icon(
                            Icons.chevron_right_rounded,
                            color: isDark ? const Color(0xFF868685) : AppTheme.textSecondary,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildFoodLogPanel() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeTextColor = isDark ? Colors.white : AppTheme.textPrimary;
    final cardBgColor = isDark ? const Color(0xFF1C1E1B) : AppTheme.glassBackground;
    final borderColor = isDark ? const Color(0xFF323530) : AppTheme.glassBorder;

    final selectedDate = ref.watch(selectedDateProvider);
    final dailyStats = ref.watch(dailyMetricsProvider(selectedDate));
    final List<dynamic> loggedItems = dailyStats['logged_items'] ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: cardBgColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: borderColor, width: 1.0),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.restaurant_rounded,
                      color: AppTheme.accentCyan,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'ADD MEAL LOG',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        color: themeTextColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Track what you eat using AI, voice, or quick manual entries.',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 28),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildCircularLogButton(
                        icon: Icons.camera_alt_rounded,
                        label: 'Photo',
                        onTap: _triggerDirectPhotoLog,
                      ),
                      _buildCircularLogButton(
                        icon: Icons.qr_code_scanner_rounded,
                        label: 'Barcode',
                        onTap: () => _openFoodLogger(1),
                      ),
                      _buildCircularLogButton(
                        icon: Icons.mic_rounded,
                        label: 'Voice',
                        onTap: _openFoodLoggerWithVoice,
                      ),
                      _buildCircularLogButton(
                        icon: Icons.edit_note_rounded,
                        label: 'Describe',
                        onTap: () => _openFoodLogger(3),
                      ),
                      _buildCircularLogButton(
                        icon: Icons.post_add_rounded,
                        label: 'Manual',
                        onTap: () => _openFoodLogger(4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Today's Entries",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                  color: isDark ? Colors.white : AppTheme.textPrimary,
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const FoodHistoryScreen(),
                    ),
                  );
                },
                child: const Text(
                  'VIEW ALL',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.accentCyan,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildFoodJournalFeed(loggedItems),
        ],
      ),
    );
  }

  Widget _buildCircularLogButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final buttonBgColor = isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05);
    final borderColor = isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08);
    final textColor = isDark ? Colors.white : AppTheme.textPrimary;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: buttonBgColor,
              shape: BoxShape.circle,
              border: Border.all(color: borderColor, width: 1.0),
            ),
            child: Icon(
              icon,
              color: AppTheme.accentCyan,
              size: 22,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  void _openFoodLogger(int initialTab) {
    showDialog(
      context: context,
      builder: (context) => FoodLoggerDialog(initialTab: initialTab),
    );
  }

  void _triggerDirectPhotoLog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF121214) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_rounded, color: AppTheme.accentCyan),
                title: Text(
                  'Take Photo',
                  style: TextStyle(
                    color: isDark ? Colors.white : AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  ImagePickerHelper.pickImage((base64, name, filePath) {
                    _openFoodLoggerWithImage(base64);
                  }, fromCamera: true);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: AppTheme.accentCyan),
                title: Text(
                  'Upload Photo',
                  style: TextStyle(
                    color: isDark ? Colors.white : AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  ImagePickerHelper.pickImage((base64, name, filePath) {
                    _openFoodLoggerWithImage(base64);
                  }, fromCamera: false);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _openFoodLoggerWithImage(String base64) {
    showDialog(
      context: context,
      builder: (context) => FoodLoggerDialog(initialTab: 0, initialImageBase64: base64),
    );
  }

  void _openFoodLoggerWithVoice() {
    showDialog(
      context: context,
      builder: (context) => const FoodLoggerDialog(initialTab: 2, autoStartVoice: true),
    );
  }

  Widget _buildAppleTabItem(String title, int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _activeSectionTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _activeSectionTab = index;
          });
          // Check camera status when switching tabs
          final activeTab = ref.read(activeTabProvider);
          final isCurrentRoute = ModalRoute.of(context)?.isCurrent ?? true;
          _checkCameraLifecycle(activeTab, isCurrentRoute);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected 
                ? (isDark ? AppTheme.accentCyan : Colors.white) 
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected && !isDark
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                color: isSelected 
                    ? (isDark ? Colors.black : AppTheme.textPrimary) 
                    : AppTheme.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVerticalDivider(bool isDark) {
    return Container(
      width: 1,
      height: 16,
      color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08),
    );
  }

  Widget _buildActionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? AppTheme.glassBorder : Colors.black.withOpacity(0.1),
            width: 1.0,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppTheme.accentCyan, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isDark ? Colors.white : AppTheme.textPrimary,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getGradeColor(String grade, bool isDark) {
    switch (grade.toUpperCase()) {
      case 'A':
      case 'B':
        return isDark ? AppTheme.accentEmerald : const Color(0xFF054D28);
      case 'C':
      case 'D':
        return isDark ? const Color(0xFFFF9F0A) : const Color(0xFFD87000);
      case 'E':
        return AppTheme.accentCoral;
      default:
        return AppTheme.textSecondary;
    }
  }

  void _showAnalyserHelpSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF121214) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.center_focus_strong_rounded, color: AppTheme.accentCyan, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      'About Zivo Analyser',
                      style: TextStyle(
                        color: isDark ? Colors.white : AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Zivo Analyser parses product parameters and details to guide your decisions:',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : AppTheme.textPrimary,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                _buildAnalyserHelpItem(Icons.qr_code_scanner_rounded, 'Barcode Scanner', 'Align product barcode in the scan window to automatically fetch ingredients and nutritional scores.'),
                _buildAnalyserHelpItem(Icons.camera_alt_rounded, 'Image / Ingredient Scan', 'Take a photo of a product label or ingredient list to extract data using optical character recognition (OCR).'),
                _buildAnalyserHelpItem(Icons.category_rounded, 'Multi-Category Support', 'AI automatically categorizes the scanned item into Food, Supplements, or Skincare, providing targeted metrics for each.'),
                _buildAnalyserHelpItem(Icons.auto_awesome_rounded, 'Health Suitability Checks', 'Analyzes ingredients for potential toxins, allergens, additives, and fitness goal matching.'),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentCyan,
                    minimumSize: const Size(double.infinity, 44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Got it', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnalyserHelpItem(IconData icon, String title, String desc) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.accentCyan, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isDark ? Colors.white : AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFoodJournalFeed(List<dynamic> loggedItems) {
    if (loggedItems.isEmpty) {
      return GlassCard(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            Icon(
              Icons.restaurant_rounded,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withOpacity(0.15)
                  : Colors.black.withOpacity(0.1),
              size: 36,
            ),
            const SizedBox(height: 8),
            const Text(
              'No food logged yet today.',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? const Color(0xFF121214) : AppTheme.glassBackground;
    final borderColor = isDark ? const Color(0xFF2C2C2E) : AppTheme.glassBorder;
    final textColor = isDark ? Colors.white : AppTheme.textPrimary;
    final textMutedColor = isDark ? const Color(0xFFC5C9AC) : AppTheme.textSecondary;

    return Column(
      children: loggedItems.reversed.map((item) {
        final String name = item['name'] ?? 'Custom Meal';
        final String meal = item['meal'] ?? 'MEAL';
        final String time = item['time'] ?? '';
        final int calories = item['calories'] ?? 0;

        // Cover picture mappings based on name or meal category
        String foodThumbUrl = 'https://lh3.googleusercontent.com/aida-public/AB6AXuADGVXZpNft1ZskNUNac_6dKCCsmODEv5PjrcVfYZ6502KWP2CSkh-oV0apT-R7_Vy-htt3Ng_bdFZNpAydisZBPfaocCADnF3G_BLw75Wc2mFVtJPgmtT1iheLN0FxRrM2afP_xt6b4HKPZgiNk_rUUPTqMkm-6bFScLfZk9vXy1QpyTyHyT7LELsH9BOITdDUVon-DUos_gvbAFxDYAYiNZnUzqvto6eLgMAarsr0s1u0qWBHP53FTLaiT9vli-ehFEfSiNH0IiM';
        if (meal.contains('BREAKFAST') || name.toLowerCase().contains('egg')) {
          foodThumbUrl = 'https://lh3.googleusercontent.com/aida-public/AB6AXuDb6VrYtGeCuwXDAWX9AyzZijMEiCa-y5TwhJuqpiYZoi3rSVBulw2NVmOnzYSSsSeE6rwks7LWdUDj5BnLRU6rzjq6r_y3igVQbN2S9vK3o3dQgKxneb8Bvnsi0jTGc-8ZIFr0OPGJRkcHGjzc1MRmO_UZEcU0s-kzijOmrXvExqy-RMA8SFaz4fFRKVG1fy80wYNlfuc1QgmbG4CrQx5pvh8IMak3OZ-2DrNWt9xtwcXmB_0JO3enXcHRs6ZLibOf0kQltKkBajg';
        } else if (name.toLowerCase().contains('shake') || name.toLowerCase().contains('protein')) {
          foodThumbUrl = 'https://lh3.googleusercontent.com/aida-public/AB6AXuAu02ztHCanw1Xo-CIsQxvODCtZXuuPSSm0Kn4ZGG3jNSR0Ffx2Q5Q9ezBZymakx28NRatfkqbjwoU2ihTQJwLgBDIWKsZzvnBRAMkgG0j6Uz0sH5-uofS3PGDzF4acLg4DHNPPHAbQwbos-7Bq3B_mc5XWzCQt_0oXTJ1EXjvahwLqze45OL8C5aVKdO-10SRju8l4451S6qP7FBAwNzwklV4Ek-SVdF9fmeejvW_NNhv5bnuC8itvhdJkQLn1txc5IlKWvspYzec';
        }

        final String? customImageUrl = item['imageUrl'];
        ImageProvider imageProvider;
        if (customImageUrl != null && customImageUrl.isNotEmpty) {
          if (customImageUrl.startsWith('http')) {
            imageProvider = NetworkImage(customImageUrl);
          } else {
            try {
              String cleaned = customImageUrl;
              final commaIndex = cleaned.indexOf(',');
              if (commaIndex != -1) {
                cleaned = cleaned.substring(commaIndex + 1);
              }
              cleaned = cleaned.replaceAll(RegExp(r'\s+'), '');
              imageProvider = MemoryImage(base64Decode(cleaned));
            } catch (e) {
              imageProvider = NetworkImage(foodThumbUrl);
            }
          }
        } else {
          imageProvider = NetworkImage(foodThumbUrl);
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: GestureDetector(
            onTap: () => _showFoodDetailsDialog(context, Map<String, dynamic>.from(item)),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBgColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor, width: 1.0),
              ),
              child: Row(
                children: [
                  // Circular Image Thumbnail
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: borderColor, width: 1.0),
                      image: DecorationImage(
                        image: imageProvider,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Title details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE8EBE6),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDark ? const Color(0xFF3A3A3C) : AppTheme.glassBorder,
                              width: 1.0,
                            ),
                          ),
                          child: Text(
                            '$meal • $time'.toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: isDark ? Colors.white : AppTheme.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Calorie value
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$calories',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: textColor,
                        ),
                      ),
                      Text(
                        'KCAL',
                        style: TextStyle(
                          fontSize: 8,
                          color: textMutedColor,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Future<dynamic> _showFoodDetailsDialog(BuildContext context, Map<String, dynamic> item, {bool startInEditMode = false}) {
    final selectedDate = ref.read(selectedDateProvider);
    final parsedDate = DateFormat('yyyy-MM-dd').parse(selectedDate);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isDayEnded = parsedDate.isBefore(today);

    final String initialName = item['name'] ?? 'Logged Meal';
    final String initialMeal = item['meal'] ?? 'MEAL';
    final String time = item['time'] ?? '8:00 AM';
    final int initialCalories = item['calories'] ?? 0;
    final int initialProtein = item['protein'] ?? 0;
    final int initialCarbs = item['carbs'] ?? 0;
    final int initialFat = item['fat'] ?? 0;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final nameController = TextEditingController(text: initialName);
    final calController = TextEditingController(text: initialCalories.toString());
    final proteinController = TextEditingController(text: initialProtein.toString());
    final carbsController = TextEditingController(text: initialCarbs.toString());
    final fatController = TextEditingController(text: initialFat.toString());

    String initialMealKey = 'snacks_cal';
    final String upperMeal = initialMeal.toUpperCase();
    if (upperMeal == 'BREAKFAST') {
      initialMealKey = 'breakfast_cal';
    } else if (upperMeal == 'LUNCH') {
      initialMealKey = 'lunch_cal';
    } else if (upperMeal == 'DINNER') {
      initialMealKey = 'dinner_cal';
    } else if (upperMeal == 'SNACKS') {
      initialMealKey = 'snacks_cal';
    } else if (upperMeal == 'EATING OUT' || upperMeal == 'OUTSIDE FOOD') {
      initialMealKey = 'outside_food_cal';
    }

    String selectedMealKey = initialMealKey;
    bool isEditing = isDayEnded ? false : startInEditMode;

    final String? imageUrl = item['imageUrl'];
    final bool hasRealImage = imageUrl != null &&
        imageUrl.isNotEmpty &&
        !imageUrl.contains('aida-public') &&
        !imageUrl.contains('photo-1546069901-ba9599a7e63c');

    return showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            Widget buildMiniMacroIndicator(String label, String value, Color color) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "$label:",
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    value,
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              );
            }

            final categories = [
              {'name': 'Breakfast', 'key': 'breakfast_cal', 'icon': Icons.egg_rounded},
              {'name': 'Lunch', 'key': 'lunch_cal', 'icon': Icons.restaurant_rounded},
              {'name': 'Dinner', 'key': 'dinner_cal', 'icon': Icons.soup_kitchen_rounded},
              {'name': 'Snacks', 'key': 'snacks_cal', 'icon': Icons.bakery_dining_rounded},
              {'name': 'Eating Out', 'key': 'outside_food_cal', 'icon': Icons.delivery_dining_rounded},
            ];

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0E0F0C) : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isDark ? const Color(0xFF2C2C2E) : AppTheme.glassBorder,
                        width: 1.0,
                      ),
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Row: Close Button & Category
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (!isEditing)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentCyan.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: AppTheme.accentCyan.withOpacity(0.3),
                                    width: 1.0,
                                  ),
                                ),
                                child: Text(
                                  selectedMealKey == 'outside_food_cal'
                                      ? 'EATING OUT'
                                      : selectedMealKey.replaceAll('_cal', '').replaceAll('_', ' ').toUpperCase(),
                                  style: const TextStyle(
                                    color: AppTheme.accentCyan,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 9,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              )
                            else
                              const Text(
                                'EDIT ENTRY',
                                style: TextStyle(
                                  color: AppTheme.accentCyan,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            // Close button
                            GestureDetector(
                              onTap: () => Navigator.of(context).pop(),
                              child: Container(
                                padding: const EdgeInsets.all(6),
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
                        const SizedBox(height: 18),

                        if (isEditing) ...[
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
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: categories.map((cat) {
                              final isSelected = selectedMealKey == cat['key'];
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    selectedMealKey = cat['key'] as String;
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppTheme.accentCyan
                                        : Colors.white.withOpacity(0.03),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppTheme.accentCyan
                                          : Colors.white.withOpacity(0.08),
                                      width: 1.0,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        cat['icon'] as IconData,
                                        size: 11,
                                        color: isSelected ? Colors.black : Colors.white70,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        cat['name'] as String,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: isSelected ? Colors.black : Colors.white70,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Meal Name
                        if (!isEditing)
                          Text(
                            nameController.text,
                            style: TextStyle(
                              color: isDark ? Colors.white : AppTheme.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          )
                        else ...[
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
                            controller: nameController,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: isDark ? const Color(0xFF121214) : Colors.black.withOpacity(0.02),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                        const SizedBox(height: 8),

                        // Time indicator row
                        if (!isEditing)
                          Row(
                            children: [
                              const Icon(
                                Icons.access_time_rounded,
                                color: AppTheme.textSecondary,
                                size: 13,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Logged at $time',
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),

                        if (hasRealImage) ...[
                          const SizedBox(height: 16),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: () {
                              final imgStr = imageUrl;
                              Widget? imageWidget;
                              if (imgStr.startsWith('http')) {
                                imageWidget = Image.network(
                                  imgStr,
                                  fit: BoxFit.cover,
                                  height: 160,
                                  width: double.infinity,
                                  errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                                );
                              } else {
                                try {
                                  String cleaned = imgStr;
                                  final commaIndex = cleaned.indexOf(',');
                                  if (commaIndex != -1) {
                                    cleaned = cleaned.substring(commaIndex + 1);
                                  }
                                  cleaned = cleaned.replaceAll(RegExp(r'\s+'), '');
                                  imageWidget = Image.memory(
                                    base64Decode(cleaned),
                                    fit: BoxFit.cover,
                                    height: 160,
                                    width: double.infinity,
                                    errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                                  );
                                } catch (e) {
                                  imageWidget = const SizedBox.shrink();
                                }
                              }
                              return imageWidget;
                            }(),
                          ),
                        ],
                        const SizedBox(height: 20),

                        // Calories field styled like 3rd screenshot
                        if (!isEditing)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(left: 4, bottom: 6),
                                child: Text(
                                  "Calories",
                                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                              Container(
                                width: double.infinity,
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
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Text('🔥', style: TextStyle(fontSize: 20)),
                                        const SizedBox(width: 12),
                                        Text(
                                          calController.text,
                                          style: TextStyle(
                                            color: isDark ? Colors.white : Colors.black,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      "kcal",
                                      style: TextStyle(
                                        color: isDark ? const Color(0xFF868685) : AppTheme.textSecondary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        else ...[
                          const Text(
                            'CALORIES',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: calController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: isDark ? const Color(0xFF121214) : Colors.black.withOpacity(0.02),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              suffixText: ' kcal',
                              suffixStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
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
                        const SizedBox(height: 12),

                        // Macros Splits styled like 3rd screenshot
                        if (!isEditing) ...[
                          const Padding(
                            padding: EdgeInsets.only(left: 4, bottom: 8),
                            child: Text(
                              "MACRONUTRIENTS",
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                            ),
                          ),
                          Row(
                            children: [
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
                                    Container(
                                      height: 48,
                                      padding: const EdgeInsets.symmetric(horizontal: 10),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF121214) : Colors.black.withOpacity(0.02),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isDark ? const Color(0xFF2C2C2E) : AppTheme.glassBorder,
                                          width: 1.0,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              const Text('🍗', style: TextStyle(fontSize: 16)),
                                              const SizedBox(width: 6),
                                              Text(
                                                proteinController.text,
                                                style: TextStyle(
                                                  color: isDark ? Colors.white : Colors.black,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Text(
                                            "g",
                                            style: TextStyle(
                                              color: isDark ? const Color(0xFF868685) : AppTheme.textSecondary,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
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
                                    Container(
                                      height: 48,
                                      padding: const EdgeInsets.symmetric(horizontal: 10),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF121214) : Colors.black.withOpacity(0.02),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isDark ? const Color(0xFF2C2C2E) : AppTheme.glassBorder,
                                          width: 1.0,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              const Text('🍚', style: TextStyle(fontSize: 16)),
                                              const SizedBox(width: 6),
                                              Text(
                                                carbsController.text,
                                                style: TextStyle(
                                                  color: isDark ? Colors.white : Colors.black,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Text(
                                            "g",
                                            style: TextStyle(
                                              color: isDark ? const Color(0xFF868685) : AppTheme.textSecondary,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
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
                                    Container(
                                      height: 48,
                                      padding: const EdgeInsets.symmetric(horizontal: 10),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF121214) : Colors.black.withOpacity(0.02),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isDark ? const Color(0xFF2C2C2E) : AppTheme.glassBorder,
                                          width: 1.0,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              const Text('🥑', style: TextStyle(fontSize: 16)),
                                              const SizedBox(width: 6),
                                              Text(
                                                fatController.text,
                                                style: TextStyle(
                                                  color: isDark ? Colors.white : Colors.black,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Text(
                                            "g",
                                            style: TextStyle(
                                              color: isDark ? const Color(0xFF868685) : AppTheme.textSecondary,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ]
                        else ...[
                          const Text(
                            'MACRONUTRIENTS (G)',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(child: _buildMiniEditField("Protein", proteinController)),
                              const SizedBox(width: 8),
                              Expanded(child: _buildMiniEditField("Carbs", carbsController)),
                              const SizedBox(width: 8),
                              Expanded(child: _buildMiniEditField("Fat", fatController)),
                            ],
                          ),
                        ],

                        if (!isEditing && item['items'] != null && (item['items'] as List).isNotEmpty) ...[
                          const SizedBox(height: 18),
                          const Text(
                            'MEAL BREAKDOWN',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0C0D0B) : Colors.black.withOpacity(0.01),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark ? const Color(0xFF232521) : AppTheme.glassBorder,
                                width: 1.0,
                              ),
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: (item['items'] as List).length,
                              separatorBuilder: (context, index) => Divider(
                                color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04),
                                height: 12,
                              ),
                              itemBuilder: (context, index) {
                                final rawItem = (item['items'] as List)[index];
                                final name = rawItem['name'] ?? rawItem['foodName'] ?? 'Ingredient';
                                final sizeVal = rawItem['servingSize'] != null ? (rawItem['servingSize'] as num).toDouble() : 1.0;
                                final sizeStr = sizeVal % 1 == 0 ? sizeVal.toInt().toString() : sizeVal.toString();
                                final unit = rawItem['servingUnit'] ?? 'piece';
                                final cal = rawItem['calories'] ?? 0;
                                final prot = rawItem['protein'] ?? 0;
                                final carb = rawItem['carbs'] ?? 0;
                                final fat = rawItem['fat'] ?? 0;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: AppTheme.accentCyan,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  name,
                                                  style: TextStyle(
                                                    color: isDark ? Colors.white : AppTheme.textPrimary,
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.bold,
                                                    letterSpacing: -0.2,
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: AppTheme.accentCyan.withOpacity(0.08),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    "$sizeStr $unit",
                                                    style: const TextStyle(
                                                      color: AppTheme.accentCyan,
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w800,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Text(
                                                  "$cal kcal",
                                                  style: TextStyle(
                                                    color: isDark ? Colors.white70 : Colors.black87,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Container(
                                                  width: 3,
                                                  height: 3,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: isDark ? Colors.white24 : Colors.black12,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                buildMiniMacroIndicator('P', '${prot}g', AppTheme.accentOrange),
                                                const SizedBox(width: 8),
                                                buildMiniMacroIndicator('C', '${carb}g', AppTheme.accentCyan),
                                                const SizedBox(width: 8),
                                                buildMiniMacroIndicator('F', '${fat}g', AppTheme.accentCoral),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],

                        const SizedBox(height: 24),

                        // Buttons section
                        if (isDayEnded)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E2124) : const Color(0xFFF5F7F4),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE8EBE6),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.lock_outline_rounded, color: isDark ? const Color(0xFF868685) : AppTheme.textSecondary, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  "Logs are locked for ended days",
                                  style: TextStyle(
                                    color: isDark ? const Color(0xFF868685) : AppTheme.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (!isEditing)
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () async {
                                    final selectedDate = ref.read(selectedDateProvider);
                                    final currentMetrics = ref.read(dailyMetricsProvider(selectedDate));
                                    final updatedMetrics = Map<String, dynamic>.from(currentMetrics);

                                    final List<dynamic> loggedItems = List<dynamic>.from(updatedMetrics['logged_items'] ?? []);
                                    int removeIndex = -1;
                                    for (int i = 0; i < loggedItems.length; i++) {
                                      final currentItem = loggedItems[i];
                                      if (currentItem['name'] == item['name'] &&
                                          currentItem['calories'] == item['calories'] &&
                                          currentItem['protein'] == item['protein'] &&
                                          currentItem['carbs'] == item['carbs'] &&
                                          currentItem['fat'] == item['fat'] &&
                                          currentItem['meal'] == item['meal'] &&
                                          currentItem['time'] == item['time']) {
                                        removeIndex = i;
                                        break;
                                      }
                                    }

                                    if (removeIndex != -1) {
                                      loggedItems.removeAt(removeIndex);
                                      updatedMetrics['logged_items'] = loggedItems;

                                      updatedMetrics[initialMealKey] = ((updatedMetrics[initialMealKey] ?? 0) - initialCalories).clamp(0, 999999);
                                      updatedMetrics['protein'] = ((updatedMetrics['protein'] ?? 0) - initialProtein).clamp(0, 999999);
                                      updatedMetrics['carbs'] = ((updatedMetrics['carbs'] ?? 0) - initialCarbs).clamp(0, 999999);
                                      updatedMetrics['fat'] = ((updatedMetrics['fat'] ?? 0) - initialFat).clamp(0, 999999);

                                      await ref.read(dailyMetricsProvider(selectedDate).notifier).saveMetrics(updatedMetrics);

                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          backgroundColor: AppTheme.accentCoral,
                                          content: Text("Deleted entry: ${initialName}"),
                                        ),
                                      );
                                    }
                                    Navigator.of(context).pop();
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: isDark ? AppTheme.accentCoral.withOpacity(0.06) : Colors.red.withOpacity(0.03),
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(
                                        color: AppTheme.accentCoral.withOpacity(0.3),
                                        width: 1.2,
                                      ),
                                    ),
                                    child: const Center(
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.delete_outline_rounded, color: AppTheme.accentCoral, size: 18),
                                          SizedBox(width: 8),
                                          Text(
                                            "Delete",
                                            style: TextStyle(
                                              color: AppTheme.accentCoral,
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      isEditing = true;
                                    });
                                  },
                                  child: Container(
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: AppTheme.accentCyan,
                                      borderRadius: BorderRadius.circular(24),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppTheme.accentCyan.withOpacity(0.2),
                                          blurRadius: 10,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: const Center(
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.edit_rounded, color: Colors.black, size: 18),
                                          SizedBox(width: 8),
                                          Text(
                                            "Edit Entry",
                                            style: TextStyle(
                                              color: Colors.black,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        else
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    if (startInEditMode) {
                                      Navigator.of(context).pop();
                                    } else {
                                      setState(() {
                                        isEditing = false;
                                        // Reset fields
                                        nameController.text = initialName;
                                        calController.text = initialCalories.toString();
                                        proteinController.text = initialProtein.toString();
                                        carbsController.text = initialCarbs.toString();
                                        fatController.text = initialFat.toString();
                                        selectedMealKey = initialMealKey;
                                      });
                                    }
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(
                                        color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
                                        width: 1.2,
                                      ),
                                    ),
                                    child: const Center(
                                      child: Text(
                                        "Cancel",
                                        style: TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () async {
                                    final selectedDate = ref.read(selectedDateProvider);
                                    final currentMetrics = ref.read(dailyMetricsProvider(selectedDate));
                                    final updatedMetrics = Map<String, dynamic>.from(currentMetrics);

                                    final String newName = nameController.text.trim();
                                    final int newCal = int.tryParse(calController.text) ?? 0;
                                    final int newProt = int.tryParse(proteinController.text) ?? 0;
                                    final int newCarb = int.tryParse(carbsController.text) ?? 0;
                                    final int newFat = int.tryParse(fatController.text) ?? 0;

                                    final List<dynamic> loggedItems = List<dynamic>.from(updatedMetrics['logged_items'] ?? []);
                                    int updateIndex = -1;
                                    for (int i = 0; i < loggedItems.length; i++) {
                                      final currentItem = loggedItems[i];
                                      if (currentItem['name'] == item['name'] &&
                                          currentItem['calories'] == item['calories'] &&
                                          currentItem['protein'] == item['protein'] &&
                                          currentItem['carbs'] == item['carbs'] &&
                                          currentItem['fat'] == item['fat'] &&
                                          currentItem['meal'] == item['meal'] &&
                                          currentItem['time'] == item['time']) {
                                        updateIndex = i;
                                        break;
                                      }
                                    }

                                    if (updateIndex != -1) {
                                      // 1. Subtract original values from daily totals
                                      updatedMetrics[initialMealKey] = ((updatedMetrics[initialMealKey] ?? 0) - initialCalories).clamp(0, 999999);
                                      updatedMetrics['protein'] = ((updatedMetrics['protein'] ?? 0) - initialProtein).clamp(0, 999999);
                                      updatedMetrics['carbs'] = ((updatedMetrics['carbs'] ?? 0) - initialCarbs).clamp(0, 999999);
                                      updatedMetrics['fat'] = ((updatedMetrics['fat'] ?? 0) - initialFat).clamp(0, 999999);

                                      // 2. Add new values to daily totals
                                      updatedMetrics[selectedMealKey] = ((updatedMetrics[selectedMealKey] ?? 0) + newCal).clamp(0, 999999);
                                      updatedMetrics['protein'] = ((updatedMetrics['protein'] ?? 0) + newProt).clamp(0, 999999);
                                      updatedMetrics['carbs'] = ((updatedMetrics['carbs'] ?? 0) + newCarb).clamp(0, 999999);
                                      updatedMetrics['fat'] = ((updatedMetrics['fat'] ?? 0) + newFat).clamp(0, 999999);

                                      // 3. Update logged item entry
                                      final String newMealLabel = selectedMealKey == 'outside_food_cal'
                                          ? 'EATING OUT'
                                          : selectedMealKey.replaceAll('_cal', '').replaceAll('_', ' ').toUpperCase();

                                      loggedItems[updateIndex] = {
                                        ...loggedItems[updateIndex],
                                        'name': newName.isNotEmpty ? newName : "Logged Meal",
                                        'calories': newCal,
                                        'protein': newProt,
                                        'carbs': newCarb,
                                        'fat': newFat,
                                        'meal': newMealLabel,
                                      };
                                      updatedMetrics['logged_items'] = loggedItems;

                                      await ref.read(dailyMetricsProvider(selectedDate).notifier).saveMetrics(updatedMetrics);

                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          backgroundColor: AppTheme.accentEmerald,
                                          content: Text("Updated entry successfully!"),
                                        ),
                                      );
                                    }
                                    Navigator.of(context).pop();
                                  },
                                  child: Container(
                                    height: 48,
                                    decoration: BoxDecoration(
                                      gradient: AppTheme.primaryGradient,
                                      borderRadius: BorderRadius.circular(24),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppTheme.accentCyan.withOpacity(0.15),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: const Center(
                                      child: Text(
                                        "Save Changes",
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w900,
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
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailMacroCard(String label, String val, Color col, String emoji) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: col.withOpacity(0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: col.withOpacity(0.2),
          width: 1.2,
        ),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 8,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            val,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniEditField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withOpacity(0.02),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }
}

