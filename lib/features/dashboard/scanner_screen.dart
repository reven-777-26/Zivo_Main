import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:http/http.dart' as http;
import '../../core/theme.dart';
import '../../utils/image_picker_helper.dart';
import '../../services/storage_service.dart';
import '../../services/scanner/barcode_service.dart';
import '../../services/scanner/database_service.dart';
import '../../services/scanner/ocr_service.dart';
import '../../services/scanner/ai_analysis_service.dart';
import '../../services/scanner/nutrition_normalizer.dart';

class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  String _selectedCategory = 'Food'; // 'Food', 'Supplement', 'Skincare'
  bool _isScanning = false;
  String _loadingStep = '';
  Map<String, dynamic>? _scanResult;

  final _scanInputController = TextEditingController();
  String? _selectedImageBase64;
  String? _selectedImageName;
  final List<Map<String, dynamic>> _scanHistory = [];

  @override
  void dispose() {
    _scanInputController.dispose();
    super.dispose();
  }

  // Mock Database of Products
  final Map<String, List<Map<String, dynamic>>> _productDatabase = {
    'Food': [
      {
        'name': 'Oats & Berries Porridge',
        'rating': 'Good',
        'ratingColor': AppTheme.accentEmerald,
        'imageIcon': Icons.breakfast_dining_rounded,
        'calories': '320 kcal',
        'macros': 'P: 24g  C: 48g  F: 6g',
        'proteinQuality': '92/100 (High Essential Amino Acids)',
        'ingredients': [
          'Organic Rolled Oats',
          'Whey Protein Isolate',
          'Freeze-dried Blueberries',
          'Stevia Leaf Extract',
        ],
        'warnings': [],
        'acneScore': '0/5 (Safe for skin)',
      },
      {
        'name': 'Processed Nacho Chips',
        'rating': 'Avoid',
        'ratingColor': AppTheme.accentCoral,
        'imageIcon': Icons.cookie_rounded,
        'calories': '540 kcal',
        'macros': 'P: 5g  C: 62g  F: 28g',
        'proteinQuality': '18/100 (Incomplete Plant Protein)',
        'ingredients': [
          'Ground Yellow Corn',
          'Canola Oil',
          'Monosodium Glutamate (MSG)',
          'Artificial Yellow 5 Dye',
          'Excess Sodium',
        ],
        'warnings': [
          'MSG Allergen Trigger',
          'High Saturated Trans-Fats',
          'Artificial Food Dyes',
        ],
        'acneScore': '4/5 (High Glycemic Index - Comedogenic)',
      },
    ],
    'Supplement': [
      {
        'name': 'Hydrolyzed Whey Isolate',
        'rating': 'Good',
        'ratingColor': AppTheme.accentEmerald,
        'imageIcon': Icons.fitness_center_rounded,
        'calories': '120 kcal',
        'macros': 'P: 26g  C: 1g  F: 0.5g',
        'proteinQuality': '98/100 (Supreme Biological Value)',
        'ingredients': [
          'Hydrolyzed Whey Protein Isolate',
          'Natural Cocoa Powder',
          'Lecithin',
          'Sucralose',
        ],
        'warnings': [],
        'acneScore': '1/5 (Dairy derivative - moderate caution)',
      },
      {
        'name': 'Nitro Extreme Pre-Workout',
        'rating': 'Moderate',
        'ratingColor': AppTheme.accentOrange,
        'imageIcon': Icons.bolt_rounded,
        'calories': '15 kcal',
        'macros': 'P: 0g  C: 2g  F: 0g',
        'proteinQuality': '0/100 (No Protein)',
        'ingredients': [
          'Beta-Alanine',
          'Caffeine Anhydrous (350mg)',
          'L-Arginine',
          'Artificial Fruit Flavor',
          'Acesulfame Potassium',
        ],
        'warnings': [
          'Extreme Caffeine Level (350mg)',
          'Artificial Sweeteners Alert',
          'Beta-Alanine Tingles Trigger',
        ],
        'acneScore': '0/5 (Safe)',
      },
    ],
    'Skincare': [
      {
        'name': 'Niacinamide 10% Zinc Serum',
        'rating': 'Good',
        'ratingColor': AppTheme.accentEmerald,
        'imageIcon': Icons.clean_hands_rounded,
        'calories': 'N/A',
        'macros': 'N/A',
        'proteinQuality': 'N/A',
        'ingredients': [
          'Aqua',
          'Niacinamide (Vitamin B3)',
          'Zinc PCA',
          'Phenoxyethanol',
          'Tamarind Seed Gum',
        ],
        'warnings': [],
        'acneScore': '0/5 (Safe - Calms Active Acne)',
      },
      {
        'name': 'Ultra Fragrant Comedo Cream',
        'rating': 'Avoid',
        'ratingColor': AppTheme.accentCoral,
        'imageIcon': Icons.opacity_rounded,
        'calories': 'N/A',
        'macros': 'N/A',
        'proteinQuality': 'N/A',
        'ingredients': [
          'Isopropyl Myristate',
          'Mineral Oil',
          'Synthetic Parfum',
          'Coconut Oil Derivative',
          'Parabens',
        ],
        'warnings': [
          'High Synthetic Fragrance Allergen',
          'Paraben Preservatives',
        ],
        'acneScore': '5/5 (Highly Comedogenic - Blocks Pores)',
      },
    ],
  };

  int _dbIndex = 0;

  Future<void> _triggerScan() async {
    final String query = _scanInputController.text.trim();
    String queryText = query;

    // Smart cleanup of filename to extract searchable text if query is empty
    if (queryText.isEmpty && _selectedImageName != null) {
      String cleanName = _selectedImageName!;
      final lastDot = cleanName.lastIndexOf('.');
      if (lastDot != -1) {
        cleanName = cleanName.substring(0, lastDot);
      }
      cleanName = cleanName.replaceAll(RegExp(r'[-_\.]'), ' ');
      cleanName = cleanName.replaceAll(RegExp(r'\b(product|images|selected|screenshot|photo)\b', caseSensitive: false), '');
      cleanName = cleanName.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (cleanName.isNotEmpty) {
        queryText = cleanName;
      }
    }

    // Default fallbacks if no query text at all
    if (queryText.isEmpty) {
      queryText = _selectedCategory == 'Food'
          ? 'Oats & Berries Porridge'
          : (_selectedCategory == 'Supplement'
              ? 'Hydrolyzed Whey Isolate'
              : 'Niacinamide 10% Zinc Serum');
    }

    setState(() {
      _isScanning = true;
      _scanResult = null;
      _loadingStep = "[Step 1/4] Running Barcode Preprocessing & Decoding...";
    });

    try {
      // 1. First attempt barcode decoding using BarcodeService
      final String? decodedBarcode = await BarcodeService.preprocessAndDecode(
        imageBase64: _selectedImageBase64,
        imageName: _selectedImageName,
        textQuery: query.isNotEmpty ? query : null,
        onProgress: (step) {
          setState(() {
            _loadingStep = "[Step 1/4] $step";
          });
        },
      );

      ScannedProduct? finalProduct;
      // 2. If barcode detected, sequentially query databases
      if (decodedBarcode != null) {
        queryText = decodedBarcode;
        setState(() {
          _loadingStep = "[Step 2/4] Querying Global Registries...";
        });
        finalProduct = await DatabaseService.lookupBarcode(
          barcode: decodedBarcode,
          preferredCategory: _selectedCategory,
          onProgress: (step) {
            setState(() {
              _loadingStep = "[Step 2/4] $step";
            });
          },
        );
      }

      // 3. If barcode database fails or no barcode detected, perform OCR
      if (finalProduct == null) {
        setState(() {
          _loadingStep = "[Step 3/4] Parsing Label via High-Fidelity OCR...";
        });
        finalProduct = await OcrService.runOcr(
          imageBase64: _selectedImageBase64,
          textQuery: query.isNotEmpty ? query : null,
          category: _selectedCategory,
          imageName: _selectedImageName,
          onProgress: (step) {
            setState(() {
              _loadingStep = "[Step 3/4] $step";
            });
          },
        );
      }

      // 4. If OCR fails or incomplete, fallback to ChatGPT Vision/Text Estimator
      if (finalProduct == null) {
        setState(() {
          _loadingStep = "[Step 4/4] Activating ChatGPT Vision Estimator...";
        });
        finalProduct = await AiAnalysisService.analyzeProduct(
          imageBase64: _selectedImageBase64,
          imageName: _selectedImageName,
          queryText: queryText,
          category: _selectedCategory,
          onProgress: (step) {
            setState(() {
              _loadingStep = "[Step 4/4] $step";
            });
          },
        );
      }

      // Set final scanned result to state and insert to history
      final resultJson = finalProduct.toJson();
      setState(() {
        _scanResult = resultJson;
        _scanHistory.insert(0, resultJson);
        _isScanning = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Scan complete: ${finalProduct.name} analyzed via ${finalProduct.method}!'),
          backgroundColor: finalProduct.ratingColor,
          duration: const Duration(seconds: 4),
        ),
      );

    } catch (e) {
      debugPrint("Scanner pipeline failed: $e");
      setState(() {
        _isScanning = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aura Vision Lens pipeline error. Please try again.'),
          backgroundColor: AppTheme.accentCoral,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Ambient Background Glows (Cohesive with other screens)
          if (isDark) ...[
            Positioned(
              top: -60,
              right: -60,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.accentPurple.withOpacity(0.08),
                ),
              ).animate(onPlay: (c) => c.repeat(reverse: true))
                  .scale(begin: const Offset(1, 1), end: const Offset(1.15, 1.15), duration: 8.seconds, curve: Curves.easeInOut)
                  .custom(builder: (context, val, child) => ImageFiltered(
                        imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                        child: child,
                      )),
            ),
            Positioned(
              bottom: 120,
              left: -80,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.accentCyan.withOpacity(0.06),
                ),
              ).animate(onPlay: (c) => c.repeat(reverse: true))
                  .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 10.seconds, curve: Curves.easeInOut)
                  .custom(builder: (context, val, child) => ImageFiltered(
                        imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                        child: child,
                      )),
            ),
          ],

          SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(
                left: 20,
                right: 20,
                top: 12,
                bottom: 120,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Aura Vision Lens',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Point lens to analyze product ingredients, micro-nutrient qualities, and safety indexes instantly.',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 16),

                  // Categories selector row
                  Row(
                    children: ['Food', 'Supplement', 'Skincare'].map((cat) {
                      final selected = _selectedCategory == cat;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedCategory = cat;
                              _scanResult = null;
                            });
                          },
                          child: Container(
                            height: 38,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              gradient: selected
                                  ? AppTheme.primaryGradient
                                  : null,
                              color: selected
                                  ? null
                                  : (isDark
                                        ? Colors.white.withOpacity(0.03)
                                        : Colors.black.withOpacity(0.015)),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: selected
                                    ? Colors.transparent
                                    : AppTheme.glassBorder,
                                width: 1.0,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  cat == 'Food'
                                      ? Icons.restaurant_rounded
                                      : cat == 'Supplement'
                                          ? Icons.health_and_safety_rounded
                                          : Icons.face_retouching_natural_rounded,
                                  size: 14,
                                  color: selected ? Colors.white : AppTheme.textSecondary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  cat,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: selected
                                        ? Colors.white
                                        : AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
              const SizedBox(height: 20),

              // Mock Camera Viewport frame
              Center(
                child: GlassCard(
                  width: 320,
                  height: 240,
                  padding: EdgeInsets.zero,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Scanner corner visual guides
                      Positioned(
                        top: 24,
                        left: 24,
                        child: Container(
                          width: 24,
                          height: 2,
                          color: AppTheme.accentCyan,
                        ),
                      ),
                      Positioned(
                        top: 24,
                        left: 24,
                        child: Container(
                          width: 2,
                          height: 24,
                          color: AppTheme.accentCyan,
                        ),
                      ),
                      Positioned(
                        top: 24,
                        right: 24,
                        child: Container(
                          width: 24,
                          height: 2,
                          color: AppTheme.accentCyan,
                        ),
                      ),
                      Positioned(
                        top: 24,
                        right: 24,
                        child: Container(
                          width: 2,
                          height: 24,
                          color: AppTheme.accentCyan,
                        ),
                      ),
                      Positioned(
                        bottom: 24,
                        left: 24,
                        child: Container(
                          width: 24,
                          height: 2,
                          color: AppTheme.accentCyan,
                        ),
                      ),
                      Positioned(
                        bottom: 24,
                        left: 24,
                        child: Container(
                          width: 2,
                          height: 24,
                          color: AppTheme.accentCyan,
                        ),
                      ),
                      Positioned(
                        bottom: 24,
                        right: 24,
                        child: Container(
                          width: 24,
                          height: 2,
                          color: AppTheme.accentCyan,
                        ),
                      ),
                      Positioned(
                        bottom: 24,
                        right: 24,
                        child: Container(
                          width: 2,
                          height: 24,
                          color: AppTheme.accentCyan,
                        ),
                      ),

                      if (_isScanning) ...[
                        // Neon animated scan beam
                        Container(
                              width: 260,
                              height: 4,
                              decoration: BoxDecoration(
                                color: AppTheme.accentCyan,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.accentCyan.withOpacity(0.6),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            )
                            .animate(
                              onPlay: (controller) =>
                                  controller.repeat(reverse: true),
                            )
                            .slideY(
                              begin: -20,
                              end: 20,
                              duration: 1200.ms,
                              curve: Curves.easeInOut,
                            ),
                      ],

                      // Show picked image preview if selected
                      if (_selectedImageBase64 != null)
                        Positioned.fill(
                          child: Opacity(
                            opacity: _isScanning ? 0.5 : 1.0,
                            child: Image.memory(
                              base64Decode(_selectedImageBase64!),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),

                      GestureDetector(
                        onTap: _isScanning
                            ? null
                            : () {
                                ImagePickerHelper.pickImage((base64, name) {
                                  setState(() {
                                    _selectedImageBase64 = base64;
                                    _selectedImageName = name;
                                    _scanResult = null;
                                  });
                                });
                              },
                        child: Container(
                          width: double.infinity,
                          height: double.infinity,
                          color: Colors.transparent,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              if (_selectedImageBase64 == null)
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _selectedCategory == 'Food'
                                          ? Icons.restaurant_menu_rounded
                                          : (_selectedCategory == 'Supplement'
                                              ? Icons.health_and_safety_rounded
                                              : Icons.face_retouching_natural_rounded),
                                      size: 48,
                                      color: AppTheme.textSecondary.withOpacity(0.3),
                                    ),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'Upload Product/Barcode Image',
                                      style: TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      '(Tap to pick photo)',
                                      style: TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              if (_selectedImageBase64 != null) ...[
                                if (_isScanning)
                                  const Center(
                                    child: CircularProgressIndicator(
                                      color: AppTheme.accentCyan,
                                    ),
                                  ),
                                Positioned(
                                  bottom: 12,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.65),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.edit_rounded, color: AppTheme.accentCyan, size: 12),
                                        const SizedBox(width: 4),
                                        Text(
                                          _selectedImageName != null && _selectedImageName!.length > 25
                                              ? '${_selectedImageName!.substring(0, 22)}...'
                                              : (_selectedImageName ?? 'Image'),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      if (_isScanning)
                        Positioned(
                          bottom: 16,
                          left: 16,
                          right: 16,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.75),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppTheme.accentCyan.withOpacity(0.3),
                                    width: 1.0,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        color: AppTheme.accentCyan,
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _loadingStep,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Product Search / Barcode Input field
              const Text(
                'PRODUCT TO SCAN / INPUT DESCRIPTION / BARCODE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.02),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.glassBorder, width: 1.0),
                ),
                child: TextField(
                  controller: _scanInputController,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: _selectedCategory == 'Food'
                        ? 'e.g. 3017620422003 (Nutella), Diet Coke, Oats...'
                        : _selectedCategory == 'Supplement'
                            ? 'e.g. Whey Isolate, Creatine Monohydrate...'
                            : 'e.g. Niacinamide Serum, Clay Mask, SPF 50...',
                    hintStyle: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    suffixIcon: _scanInputController.text.isNotEmpty || _selectedImageBase64 != null
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, color: AppTheme.textSecondary, size: 18),
                            onPressed: () {
                              setState(() {
                                _scanInputController.clear();
                                _selectedImageBase64 = null;
                                _selectedImageName = null;
                                _scanResult = null;
                              });
                            },
                          )
                        : null,
                  ),
                  onChanged: (val) {
                    setState(() {});
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Scan Trigger button
              GestureDetector(
                onTap: _isScanning ? null : _triggerScan,
                child: Container(
                  width: double.infinity,
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
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.qr_code_scanner_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Start AI Barcode & Product Scan',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 4. SCAN RESULT PANEL
              if (_scanResult != null) _buildScanResultPanel(_scanResult!),

              // 5. RECENT SCANS HISTORY
              if (_scanHistory.isNotEmpty) ...[
                const SizedBox(height: 32),
                const Row(
                  children: [
                    Icon(
                      Icons.history_rounded,
                      color: AppTheme.accentPurple,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Recent Scans History',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _scanHistory.length,
                  itemBuilder: (context, index) {
                    final item = _scanHistory[index];
                    final String name = item['name'] ?? 'Product';
                    final String rating = item['rating'] ?? 'Unknown';
                    final Color ratingColor = item['ratingColor'] ?? AppTheme.textSecondary;
                    final IconData icon = item['imageIcon'] ?? Icons.fastfood_rounded;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _scanResult = item;
                          });
                        },
                        child: GlassCard(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: ratingColor.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: ratingColor.withOpacity(0.2),
                                    width: 1.0,
                                  ),
                                ),
                                child: Center(
                                  child: Icon(icon, color: ratingColor, size: 20),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Overall Rating: $rating',
                                      style: TextStyle(
                                        color: ratingColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.arrow_forward_ios_rounded,
                                color: AppTheme.textSecondary,
                                size: 14,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    ],
      ),
    );
  }

  Widget _buildScanResultPanel(Map<String, dynamic> item) {
    final String name = item['name'] ?? 'Product';
    final String rating = item['rating'] ?? 'Unknown';
    final Color ratingColor = item['ratingColor'] ?? AppTheme.textSecondary;
    final IconData icon = item['imageIcon'] ?? Icons.fastfood_rounded;
    final String calories = item['calories'] ?? '';
    final String macros = item['macros'] ?? '';
    final String pQuality = item['proteinQuality'] ?? '';
    final List<dynamic> ingredients = item['ingredients'] ?? [];
    final List<dynamic> warnings = item['warnings'] ?? [];
    final String acne = item['acneScore'] ?? '';
    final String source = item['source'] ?? 'Database';
    final String confidence = item['confidence'] ?? 'LOW';
    final String method = item['method'] ?? 'Multimodal Estimation';
    final String servingSize = item['servingSize'] ?? '1 serving';

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.analytics_rounded,
                color: AppTheme.accentPurple,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Aura Lens Ingredients Review',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 12),

          GlassCard(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Header details
                Row(
                  children: [
                    // Abstract mock image thumb
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: ratingColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: ratingColor.withOpacity(0.2),
                          width: 1.0,
                        ),
                      ),
                      child: Center(
                        child: Icon(icon, color: ratingColor, size: 24),
                      ),
                    ),
                    const SizedBox(width: 14),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              // Overall Rating
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: ratingColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: ratingColor.withOpacity(0.3), width: 0.8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      rating.toLowerCase() == 'good' 
                                          ? Icons.check_circle_outline_rounded 
                                          : (rating.toLowerCase() == 'avoid' 
                                              ? Icons.highlight_off_rounded 
                                              : Icons.info_outline),
                                      size: 11,
                                      color: ratingColor,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Rating: $rating',
                                      style: TextStyle(
                                        color: ratingColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Data Source
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.04),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppTheme.glassBorder, width: 0.8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      source.toLowerCase().contains('api') || source.toLowerCase().contains('database') || source.toLowerCase().contains('fact')
                                          ? Icons.storage_rounded
                                          : (source.toLowerCase().contains('ocr') 
                                              ? Icons.document_scanner_rounded 
                                              : Icons.auto_awesome_rounded),
                                      size: 11,
                                      color: AppTheme.accentCyan,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Source: $source',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Confidence Score
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: confidence == 'HIGH'
                                      ? AppTheme.accentEmerald.withOpacity(0.12)
                                      : (confidence == 'MEDIUM'
                                          ? AppTheme.accentOrange.withOpacity(0.12)
                                          : AppTheme.accentPurple.withOpacity(0.12)),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: confidence == 'HIGH'
                                        ? AppTheme.accentEmerald.withOpacity(0.3)
                                        : (confidence == 'MEDIUM'
                                            ? AppTheme.accentOrange.withOpacity(0.3)
                                            : AppTheme.accentPurple.withOpacity(0.3)),
                                    width: 0.8,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.verified_user_rounded,
                                      size: 11,
                                      color: confidence == 'HIGH'
                                          ? AppTheme.accentEmerald
                                          : (confidence == 'MEDIUM'
                                              ? AppTheme.accentOrange
                                              : AppTheme.accentPurple),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Confidence: $confidence',
                                      style: TextStyle(
                                        color: confidence == 'HIGH'
                                            ? AppTheme.accentEmerald
                                            : (confidence == 'MEDIUM'
                                                ? AppTheme.accentOrange
                                                : AppTheme.accentPurple),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Scan Method Used
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.04),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppTheme.glassBorder, width: 0.8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.layers_outlined,
                                      size: 11,
                                      color: AppTheme.accentPurple,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Method: $method',
                                      style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Serving Size
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.04),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppTheme.glassBorder, width: 0.8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.scale_rounded,
                                      size: 11,
                                      color: AppTheme.accentOrange,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Serving: $servingSize',
                                      style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(color: AppTheme.glassBorder, height: 24),

                // Macro readout card (if available)
                if (calories != 'N/A' && calories.isNotEmpty) ...[
                  const Text(
                    'PRODUCT NUTRITION REGISTER',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.accentCyan,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Calories: $calories',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Macros: $macros',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Protein quality scores (if applicable)
                if (pQuality != 'N/A' && pQuality.isNotEmpty) ...[
                  const Text(
                    'PROTEIN BIOLOGICAL VALUE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.accentOrange,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    pQuality,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Acne ratings (skincare / foods Comedogenic score)
                const Text(
                  'DERMA SAFETY SCORE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.accentPurple,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  acne,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 14),

                // Warning flags (Allergens, MSG, artificial colors)
                if (warnings.isNotEmpty) ...[
                  const Text(
                    'CRITICAL ADDITIVES WARNING',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.accentCoral,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...warnings.map(
                    (w) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: AppTheme.accentCoral,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              w,
                              style: const TextStyle(
                                color: AppTheme.accentCoral,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Ingredients lists breakdown
                const Text(
                  'INGREDIENTS GLOSSARY',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textSecondary,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: ingredients.map((ing) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppTheme.glassBorder,
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        ing,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),
        ],
      ),
    );
  }
}
