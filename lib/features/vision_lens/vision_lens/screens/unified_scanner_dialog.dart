import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/theme.dart';
import '../../../../core/widgets/zivo_loader.dart';
import '../../../../services/scanner/camera_barcode_scanner.dart';
import '../../../../services/scanner/native_barcode_scanner.dart';
import '../../../../utils/image_picker_helper.dart';
import '../../../../utils/web_barcode_scanner.dart';
import '../../shared/providers/unified_vision_provider.dart';
import 'unified_product_detail_screen.dart';
import 'zivo_analyzer_loading_widget.dart';
import '../../../../services/audio_service.dart';

class UnifiedVisionScannerDialog extends ConsumerStatefulWidget {
  const UnifiedVisionScannerDialog({super.key});

  @override
  ConsumerState<UnifiedVisionScannerDialog> createState() => _UnifiedVisionScannerDialogState();
}

class _UnifiedVisionScannerDialogState extends ConsumerState<UnifiedVisionScannerDialog> {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  bool _isProcessingFrame = false;
  bool _isInitializing = false;
  Timer? _webFrameTimer;
  String? _errorMessage;

  final TextEditingController _barcodeCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void dispose() {
    _disposeCamera();
    _barcodeCtrl.dispose();
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
          _errorMessage = "Camera access blocked or not supported. Please upload an image instead.";
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
            debugPrint("Web dialog barcode scan frame error: $e");
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

  Future<void> _handleBarcodeScan(String barcode) async {
    if (barcode.trim().isEmpty) return;
    _disposeCamera(); // stop camera before analysis loading begins

    // Perform analysis
    await ref.read(unifiedVisionProvider.notifier).scanBarcodeAndAnalyze(
      barcode: barcode,
    );

    _dismissAndNavigate(barcode);
  }

  void _triggerTakeProductPhoto() async {
    _disposeCamera();
    ImagePickerHelper.pickImage(
      (base64, name, filePath) async {
        await ref.read(unifiedVisionProvider.notifier).analyzeFromImage(
          base64Content: base64,
          fileName: name,
        );

        final state = ref.read(unifiedVisionProvider);
        final barcodeToUse = state.currentReport.value?.barcode ?? 'unknown';
        _dismissAndNavigate(barcodeToUse);
      },
      isBarcode: true,
      fromCamera: true,
    );
  }

  void _triggerImageScan() async {
    _disposeCamera();
    ImagePickerHelper.pickImage(
      (base64, name, filePath) async {
        await ref.read(unifiedVisionProvider.notifier).analyzeFromImage(
          base64Content: base64,
          fileName: name,
        );

        final state = ref.read(unifiedVisionProvider);
        final barcodeToUse = state.currentReport.value?.barcode ?? 'unknown';
        _dismissAndNavigate(barcodeToUse);
      },
      isBarcode: true,
      fromCamera: false,
    );
  }

  void _triggerIngredientsScan() async {
    _disposeCamera();
    ImagePickerHelper.pickImage(
      (base64, name, filePath) async {
        await ref.read(unifiedVisionProvider.notifier).analyzeFromImage(
          base64Content: base64,
          fileName: name,
          isIngredientLabel: true,
        );

        final state = ref.read(unifiedVisionProvider);
        final barcodeToUse = state.currentReport.value?.barcode ?? 'unknown';
        _dismissAndNavigate(barcodeToUse);
      },
      isBarcode: true,
      fromCamera: false,
    );
  }



  void _dismissAndNavigate(String barcode) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context); // close loader dialog or scanner modal
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
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UnifiedProductDetailScreen(barcode: barcode),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final visionState = ref.watch(unifiedVisionProvider);
    final isScanning = visionState.isScanning;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Center( // Center the dialog container properly to avoid stretching full-screen
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              width: isScanning
                  ? (MediaQuery.of(context).size.width - 40).clamp(280.0, 330.0)
                  : 480,
              height: null,
              constraints: BoxConstraints(
                minHeight: isScanning ? 350 : 0,
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF121214).withOpacity(0.85)
                    : AppTheme.glassBackground.withOpacity(0.9),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark ? const Color(0xFF2C2C2E) : AppTheme.glassBorder,
                  width: 1.0,
                ),
              ),
              padding: EdgeInsets.all(isScanning ? 10 : 24),
              child: isScanning
                  ? _buildLoadingState(isDark, visionState.progressMessage)
                  : _buildScannerView(isDark),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState(bool isDark, String message) {
    return ZivoAnalyzerLoadingWidget(progressMessage: message);
  }

  Widget _buildScannerView(bool isDark) {
    final primaryTextColor = isDark ? Colors.white : AppTheme.textPrimary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.center_focus_strong_rounded, color: isDark ? AppTheme.accentCyan : const Color(0xFF054D28), size: 20),
                const SizedBox(width: 8),
                Text(
                  'Zivo analyser',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    color: isDark ? Colors.white : AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondary, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // AI auto-detects category
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.accentCyan.withOpacity(0.12) : const Color(0xFFE2F6D5),
            borderRadius: BorderRadius.circular(9999),
            border: Border.all(color: isDark ? AppTheme.accentCyan.withOpacity(0.3) : const Color(0xFFC5EDAB), width: 1.0),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome_rounded, color: isDark ? AppTheme.accentCyan : const Color(0xFF054D28), size: 14),
              const SizedBox(width: 6),
              Text(
                'AI auto-detects product type',
                style: TextStyle(color: isDark ? AppTheme.textSecondary : const Color(0xFF054D28), fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Live camera container
        Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(18), // rounded.lg (18px)
            border: Border.all(
              color: _isCameraInitialized ? AppTheme.accentCyan : AppTheme.glassBorder,
              width: 1.0, // Hairline
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
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        _errorMessage ?? 'Starting camera feed...',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _errorMessage != null ? AppTheme.accentCoral : AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),

              // Guidelines box overlay
              if (_isCameraInitialized)
                Container(
                  width: 200,
                  height: 90,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.accentCyan, width: 1.5), // Soft outline
                    borderRadius: BorderRadius.circular(8), // rounded.sm (8px)
                  ),
                ),

              // Sweeping laser
              if (_isCameraInitialized)
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(seconds: 2),
                  builder: (context, value, child) {
                    return Positioned(
                      top: 55 + (value * 90),
                      left: 40,
                      right: 40,
                      child: Container(
                        height: 2,
                        decoration: const BoxDecoration(
                          color: AppTheme.accentCyan, // Flat solid laser light (no shadow)
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Actions Row (Take Photo, Upload Photo, Ingredients)
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _triggerTakeProductPhoto,
                child: _buildSubActionBtn(Icons.camera_alt_rounded, "Take Photo", AppTheme.accentCyan),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: GestureDetector(
                onTap: _triggerImageScan,
                child: _buildSubActionBtn(Icons.photo_library_rounded, "Upload Photo", AppTheme.accentCyan),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: GestureDetector(
                onTap: _triggerIngredientsScan,
                child: _buildSubActionBtn(Icons.receipt_long_rounded, "Ingredients", AppTheme.accentCyan),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // Manual text input EAN
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 38,
                child: TextField(
                  controller: _barcodeCtrl,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: primaryTextColor, fontSize: 12),
                  decoration: InputDecoration(
                    hintText: "Or type barcode number manually...",
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
              onTap: () {
                final code = _barcodeCtrl.text.trim();
                if (code.isNotEmpty) {
                  _barcodeCtrl.clear();
                  _handleBarcodeScan(code);
                }
              },
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppTheme.accentCyan, // Action Blue flat
                  borderRadius: BorderRadius.circular(24), // button radius is canonical 24
                ),
                child: const Center(
                  child: Icon(Icons.arrow_forward_rounded, color: AppTheme.textPrimary, size: 18),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }


  Widget _buildSubActionBtn(IconData icon, String label, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(24), // button radius is canonical 24px
        border: Border.all(
          color: isDark ? AppTheme.glassBorder : Colors.black.withOpacity(0.1),
          width: 1.0,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppTheme.accentCyan, size: 18),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.white : AppTheme.textPrimary,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}
