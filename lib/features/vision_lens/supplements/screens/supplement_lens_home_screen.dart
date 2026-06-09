import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme.dart';
import '../../../../utils/image_picker_helper.dart';
import '../models/supplement_product.dart';
import '../providers/supplement_vision_provider.dart';
import '../services/supplement_service.dart';
import 'supplement_product_detail_screen.dart';

class SupplementLensHomeScreen extends ConsumerStatefulWidget {
  const SupplementLensHomeScreen({super.key});

  @override
  ConsumerState<SupplementLensHomeScreen> createState() => _SupplementLensHomeScreenState();
}

class _SupplementLensHomeScreenState extends ConsumerState<SupplementLensHomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  List<Map<String, dynamic>> _searchResults = [];

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _searchResults.clear();
    });

    try {
      final results = await SupplementService.searchSupplements(query);
      setState(() {
        _searchResults = results;
      });
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registry search failed.')),
      );
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  void _triggerImageScan({bool fromCamera = false}) {
    ImagePickerHelper.pickImage(
      (base64, name, filePath) async {
        _showLoadingOverlay();
        final barcode = await ImagePickerHelper.scanBarcode(base64, filePath: filePath);
        
        if (!mounted) return;

        final notifier = ref.read(supplementVisionProvider.notifier);
        if (barcode.isNotEmpty) {
          await notifier.scanAndAnalyze(barcode: barcode);
        } else {
          await notifier.scanAndAnalyze(imageBase64: base64, searchName: name);
        }
        _dismissLoadingAndNavigate(barcode.isNotEmpty ? barcode : null);
      },
      isBarcode: true,
      fromCamera: fromCamera,
    );
  }

  void _showBarcodeManualDialog() {
    final barcodeCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppTheme.glassBackground : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: isDark ? AppTheme.glassBorder : Colors.grey.withOpacity(0.2)),
          ),
          title: const Text(
            'Enter Barcode Manually',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: TextField(
            controller: barcodeCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'e.g. 4901058851335',
              hintStyle: const TextStyle(color: AppTheme.textSecondary),
              filled: true,
              fillColor: Colors.black.withOpacity(0.2),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.glassBorder),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentCyan,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                final code = barcodeCtrl.text.trim();
                Navigator.pop(ctx);
                if (code.isNotEmpty) {
                  _startBarcodeLookup(code);
                }
              },
              child: const Text('Lookup', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _startBarcodeLookup(String barcode) async {
    _showLoadingOverlay();
    await ref.read(supplementVisionProvider.notifier).scanAndAnalyze(barcode: barcode);
    _dismissLoadingAndNavigate(barcode);
  }

  void _startRegistryProductLookup(Map<String, dynamic> rawDetails) async {
    _showLoadingOverlay();
    final name = rawDetails['product_name']?.toString() ?? 'Registry Product';
    final code = rawDetails['code']?.toString() ?? rawDetails['_id']?.toString();
    await ref.read(supplementVisionProvider.notifier).scanAndAnalyze(barcode: code, searchName: name, rawDetails: rawDetails);
    _dismissLoadingAndNavigate(code);
  }

  void _showLoadingOverlay() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return WillPopScope(
          onWillPop: () async => false,
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(32),
              margin: const EdgeInsets.symmetric(horizontal: 40),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.glassBackground : Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: AppTheme.accentCyan.withOpacity(0.3), width: 1.5),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentCyan),
                    strokeWidth: 3,
                  ),
                  SizedBox(height: 24),
                  Text(
                    'Supplement Lens AI',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, decoration: TextDecoration.none),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Extracting dosage & scoring ingredients...',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.normal, decoration: TextDecoration.none),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _dismissLoadingAndNavigate(String? barcode) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SupplementProductDetailScreen(barcode: barcode),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : AppTheme.textPrimary;
    final supplementState = ref.watch(supplementVisionProvider);

    return Scaffold(
      backgroundColor: isDark ? AppTheme.obsidianBackground : const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Row(
          children: [
            Icon(Icons.medication_rounded, color: AppTheme.accentCyan, size: 24),
            SizedBox(width: 8),
            Text(
              '💊 SUPPLEMENT LENS',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.qr_code_scanner_rounded,
                    label: 'Scan Barcode',
                    color: AppTheme.accentCyan,
                    onTap: _showBarcodeManualDialog,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.camera_alt_rounded,
                    label: 'Snap Label',
                    color: AppTheme.accentPurple,
                    onTap: () => _triggerImageScan(fromCamera: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.photo_library_rounded,
                    label: 'Upload Info',
                    color: AppTheme.accentOrange,
                    onTap: () => _triggerImageScan(fromCamera: false),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.glassBackground : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.glassBorder, width: 1),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(color: primaryTextColor),
                      decoration: const InputDecoration(
                        hintText: 'Search supplement products...',
                        hintStyle: TextStyle(color: AppTheme.textSecondary),
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _performSearch(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _performSearch,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.accentCyan.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.accentCyan.withOpacity(0.3)),
                    ),
                    child: _isSearching
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentCyan)),
                          )
                        : const Icon(Icons.search_rounded, color: AppTheme.accentCyan, size: 20),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _searchResults.isNotEmpty
                  ? _buildSearchResultsList()
                  : _buildHistoryList(supplementState.history),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        borderRadius: BorderRadius.circular(18),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.1),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResultsList() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _searchResults.length,
      itemBuilder: (context, idx) {
        final item = _searchResults[idx];
        final name = item['product_name']?.toString() ?? 'Unknown Supplement';
        final brand = item['brands']?.toString() ?? 'Generic Brand';
        final code = item['code']?.toString() ?? item['_id']?.toString() ?? 'No Barcode';

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.glassBackground : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.glassBorder),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text('$brand • $code', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.accentCyan, size: 16),
            onTap: () => _startRegistryProductLookup(item),
          ),
        );
      },
    );
  }

  Widget _buildHistoryList(List<SupplementProduct> history) {
    if (history.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_rounded, size: 48, color: AppTheme.textSecondary.withOpacity(0.3)),
            const SizedBox(height: 16),
            const Text('No Scan History', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 6),
            const Text('Scan supplement bottles to view details.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'RECENT SUPPLEMENT SCANS',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0),
              ),
              GestureDetector(
                onTap: () => ref.read(supplementVisionProvider.notifier).clearHistory(),
                child: const Text('Clear All', style: TextStyle(color: AppTheme.accentCoral, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            itemCount: history.length,
            itemBuilder: (context, idx) {
              final item = history[idx];
              Color scoreColor = AppTheme.accentCoral;
              if (item.zivoScore >= 70) scoreColor = AppTheme.accentEmerald;
              else if (item.zivoScore >= 40) scoreColor = AppTheme.accentOrange;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: AppTheme.glassBackground,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.glassBorder),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: scoreColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        item.zivoScore.toString(),
                        style: TextStyle(color: scoreColor, fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                    ),
                  ),
                  title: Text(item.productName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text('${item.brand} • ${item.barcode}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.textSecondary, size: 14),
                  onTap: () => _dismissLoadingAndNavigate(item.barcode),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
