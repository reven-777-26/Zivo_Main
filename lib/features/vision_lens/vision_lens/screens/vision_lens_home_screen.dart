import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';
import '../../../../core/theme.dart';
import '../../../../services/state_providers.dart';
import '../../../../services/scanner/camera_barcode_scanner.dart';
import '../../../../services/scanner/native_barcode_scanner.dart';
import '../../../../utils/image_picker_helper.dart';
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
    _checkCameraLifecycle();
  }

  @override
  void didUpdateWidget(covariant VisionLensHomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _checkCameraLifecycle();
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
      if (activeTab == 2) {
        _initializeCamera();
      }
    }
  }

  void _checkCameraLifecycle() {
    final activeTab = ref.watch(activeTabProvider);
    if (activeTab == 2) {
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
    try {
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
    }
  }

  void _startBarcodeScanningLoop() {
    if (_cameraController == null || !_isCameraInitialized) return;

    if (kIsWeb) {
      _webFrameTimer = Timer.periodic(const Duration(milliseconds: 700), (timer) async {
        final state = ref.read(unifiedVisionProvider);
        if (state.isScanning || _isProcessingFrame || !mounted) return;
        _isProcessingFrame = true;
        try {
          final XFile file = await _cameraController!.takePicture();
          final bytes = await file.readAsBytes();
          
          final img.Image? decoded = img.decodeImage(bytes);
          if (decoded != null) {
            final rgbaBytes = decoded.getBytes(order: img.ChannelOrder.rgba);
            final frame = ImageFrame(
              bytes: rgbaBytes,
              width: decoded.width,
              height: decoded.height,
              format: 'rgba8888',
              rotation: 0,
            );
            final barcode = await CameraBarcodeScanner.detectBarcode(frame);
            if (barcode != null && barcode.isNotEmpty && mounted) {
              _isProcessingFrame = true;
              await _handleBarcodeScan(barcode);
              _isProcessingFrame = false;
            }
          }
        } catch (e) {
          debugPrint("Web barcode scan frame error: $e");
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

  void _disposeCamera() {
    _webFrameTimer?.cancel();
    _webFrameTimer = null;
    if (_cameraController != null) {
      if (_cameraController!.value.isStreamingImages) {
        _cameraController!.stopImageStream();
      }
      _cameraController!.dispose();
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

  Future<void> _runAssetBarcodeScan() async {
    _showLoadingOverlay();
    try {
      final ByteData data = await rootBundle.load('assets/test_barcode.png');
      final List<int> bytes = data.buffer.asUint8List();
      final base64Content = base64Encode(bytes);
      final fullBase64 = "data:image/png;base64,$base64Content";

      await ref.read(unifiedVisionProvider.notifier).analyzeFromImage(
        base64Content: fullBase64,
        fileName: 'test_barcode.png',
      );

      if (!mounted) return;
      final state = ref.read(unifiedVisionProvider);
      final barcodeToUse = state.currentReport.value?.barcode ?? '4901058851335';
      _dismissLoadingAndNavigate(barcodeToUse);
    } catch (e) {
      if (!mounted) return;
      if (Navigator.canPop(context)) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load asset: $e'), backgroundColor: AppTheme.accentCoral),
      );
    }
  }

  void _showLoadingOverlay() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, child) {
            final state = ref.watch(unifiedVisionProvider);
            return WillPopScope(
              onWillPop: () async => false,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(32),
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  decoration: BoxDecoration(
                    color: AppTheme.glassBackground,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: AppTheme.accentCyan.withOpacity(0.3), width: 1.5),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentCyan),
                        strokeWidth: 3,
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Zivo Vision AI',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        state.progressMessage.isNotEmpty ? state.progressMessage : 'Analyzing product...',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
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

    return Scaffold(
      backgroundColor: isDark ? AppTheme.obsidianBackground : const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => ref.read(activeTabProvider.notifier).state = 0,
        ),
        title: const Row(
          children: [
            Icon(Icons.center_focus_strong_rounded, color: AppTheme.accentCyan, size: 22),
            SizedBox(width: 8),
            Text(
              'ZIVO VISION LENS',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 18,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded, color: Colors.white),
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
                gradient: LinearGradient(
                  colors: [
                    AppTheme.accentCyan.withOpacity(0.08),
                    AppTheme.accentPurple.withOpacity(0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.accentCyan.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, color: AppTheme.accentCyan, size: 16),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'AI auto-detects Food, Supplements & Skincare',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
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
                  color: _isCameraInitialized ? AppTheme.accentCyan : AppTheme.glassBorder,
                  width: 1.5,
                ),
                boxShadow: [
                  if (_isCameraInitialized)
                    BoxShadow(
                      color: AppTheme.accentCyan.withOpacity(0.12),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (_isCameraInitialized && _cameraController != null)
                    Positioned.fill(child: CameraPreview(_cameraController!))
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
                        border: Border.all(color: AppTheme.accentCyan, width: 2.0),
                        borderRadius: BorderRadius.circular(16),
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
                            height: 3,
                            decoration: BoxDecoration(
                              color: AppTheme.accentCyan,
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.accentCyan.withOpacity(0.8),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ],
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

            // Actions Row
            Row(
              children: [
                Expanded(
                  child: _buildActionBtn(
                    icon: Icons.photo_library_rounded,
                    label: 'Upload Product Photo',
                    color: AppTheme.accentCyan,
                    onTap: _triggerImageScan,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildActionBtn(
                    icon: Icons.bug_report_rounded,
                    label: 'Use Test Barcode',
                    color: AppTheme.accentPurple,
                    onTap: _runAssetBarcodeScan,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Manual lookup row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.glassBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.glassBorder),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _barcodeInputController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: primaryTextColor, fontSize: 13, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        hintText: 'Or type barcode digits manually...',
                        hintStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
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
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.arrow_forward_rounded, color: Colors.black, size: 18),
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
                const Text(
                  'RECENT PRODUCT SCANS',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                if (visionState.history.isNotEmpty)
                  GestureDetector(
                    onTap: () => ref.read(unifiedVisionProvider.notifier).clearHistory(),
                    child: const Text(
                      'Clear History',
                      style: TextStyle(color: AppTheme.accentCoral, fontSize: 11, fontWeight: FontWeight.bold),
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
                  color: AppTheme.glassBackground,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.glassBorder),
                ),
                child: Column(
                  children: [
                    Icon(Icons.center_focus_weak_rounded, color: AppTheme.textSecondary.withOpacity(0.3), size: 36),
                    const SizedBox(height: 10),
                    const Text(
                      'No Scan History',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Scan a barcode or upload a product photo to get started.',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
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
                  final scoreColor = _getGradeColor(item.healthGrade);
                  final categoryIcon = item.category.toLowerCase() == 'skincare'
                      ? '🧴'
                      : (item.category.toLowerCase() == 'supplement' ? '💊' : '🍔');

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.glassBackground,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.glassBorder),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: scoreColor.withOpacity(0.08),
                          border: Border.all(color: scoreColor.withOpacity(0.3), width: 1.5),
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
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      subtitle: Text(
                        '$categoryIcon ${item.brand} • ${item.category.toUpperCase()}',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.textSecondary, size: 14),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: AppTheme.glassBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.glassBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getGradeColor(String grade) {
    switch (grade.toUpperCase()) {
      case 'A':
      case 'B': return AppTheme.accentEmerald;
      case 'C':
      case 'D': return AppTheme.accentOrange;
      case 'E': return AppTheme.accentCoral;
      default: return AppTheme.textSecondary;
    }
  }
}
