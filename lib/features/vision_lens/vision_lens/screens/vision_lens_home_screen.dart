import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/theme.dart';
import '../../../../services/state_providers.dart';
import '../../../../services/scanner/camera_barcode_scanner.dart';
import '../../../../services/scanner/native_barcode_scanner.dart';
import '../../../../utils/image_picker_helper.dart';
import '../../../../utils/web_barcode_scanner.dart';
import '../../shared/providers/unified_vision_provider.dart';
import 'unified_product_detail_screen.dart';

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
    if (activeTab == 2 && isCurrentRoute) {
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentCyan),
                        strokeWidth: 2,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Zivo Analyser',
                        style: TextStyle(
                          color: isDark ? Colors.white : AppTheme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        state.progressMessage.isNotEmpty ? state.progressMessage : 'Analyzing product...',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isDark ? const Color(0xFF868685) : AppTheme.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.normal,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
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
        title: Row(
          children: [
            Icon(Icons.center_focus_strong_rounded, color: isDark ? AppTheme.accentCyan : AppTheme.textPrimary, size: 22),
            const SizedBox(width: 8),
            Text(
              'ZIVO ANALYSER',
              style: TextStyle(
                color: isDark ? Colors.white : AppTheme.textPrimary,
                fontWeight: FontWeight.w900,
                fontSize: 18,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.help_outline_rounded, color: isDark ? Colors.white : AppTheme.textPrimary),
            onPressed: () => _showAnalyserHelpSheet(context),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1C1E1B) : AppTheme.glassBackground,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isDark ? const Color(0xFF323530) : AppTheme.glassBorder,
                        width: 1.0,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: Container(
                        width: 40,
                        height: 40,
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
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      title: Text(
                        item.productName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark ? Colors.white : AppTheme.textPrimary,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: Text(
                        '$categoryIcon ${item.brand} • ${item.category.toUpperCase()}',
                        style: TextStyle(
                          color: isDark ? const Color(0xFF868685) : AppTheme.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                      trailing: Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: isDark ? const Color(0xFF868685) : AppTheme.textSecondary,
                        size: 14,
                      ),
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
                    ),
                  );
                },
              ),
            const SizedBox(height: 100),
          ],
        ),
      ),
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
        return isDark ? const Color(0xFFFFC091) : const Color(0xFFB86700);
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
}
