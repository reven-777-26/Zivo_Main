import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme.dart';
import '../../services/storage_service.dart';
import '../../services/state_providers.dart';

class FoodHistoryScreen extends ConsumerWidget {
  const FoodHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loggedDates = StorageService.getAllLoggedDates();

    final bgColor = isDark ? const Color(0xFF0E0F0C) : AppTheme.obsidianBackground;

    return Scaffold(
      backgroundColor: bgColor,
      body: Container(
        color: bgColor,
        child: Stack(
          children: [
            // No decorative background ambient glows in Wise Design System

            // Main Scroll Feed
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Premium Top Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        // Custom Glass Back button
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                              ),
                            ),
                            child: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: isDark ? Colors.white : AppTheme.textPrimary,
                              size: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Food Journal History',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                                color: isDark ? Colors.white : AppTheme.textPrimary,
                              ),
                            ),
                            Text(
                              'Lifetime logs: ${loggedDates.length} days active',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Main List Feed
                  Expanded(
                    child: loggedDates.isEmpty
                        ? _buildEmptyState(isDark)
                        : ListView.builder(
                            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 40),
                            physics: const BouncingScrollPhysics(),
                            itemCount: loggedDates.length,
                            itemBuilder: (context, index) {
                              final dateStr = loggedDates[index];
                              final parsedDate = DateFormat('yyyy-MM-dd').parse(dateStr);
                              final formattedDate = DateFormat('EEEE, MMMM d, yyyy').format(parsedDate);
                              
                              return Consumer(
                                builder: (context, ref, child) {
                                  final stats = ref.watch(dailyMetricsProvider(dateStr));
                                  final List<dynamic> items = stats['logged_items'] ?? [];
                                  
                                  final int totalCal = (((stats['breakfast_cal'] ?? 0) as num) +
                                          ((stats['lunch_cal'] ?? 0) as num) +
                                          ((stats['dinner_cal'] ?? 0) as num) +
                                          ((stats['snacks_cal'] ?? 0) as num) +
                                          ((stats['outside_food_cal'] ?? 0) as num))
                                      .toInt();

                                  final double protein = (stats['protein'] ?? 0).toDouble();
                                  final double carbs = (stats['carbs'] ?? 0).toDouble();
                                  final double fat = (stats['fat'] ?? 0).toDouble();

                                  if (items.isEmpty && totalCal == 0) {
                                    return const SizedBox.shrink(); // skip empty days in lifetime log
                                  }

                                  return Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                child: GlassCard(
                                  padding: const EdgeInsets.all(16),
                                  borderRadius: BorderRadius.circular(24),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Day Header row
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              formattedDate.toUpperCase(),
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: 0.5,
                                                color: isDark ? Colors.white : AppTheme.textPrimary,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: isDark ? AppTheme.accentCyan.withOpacity(0.12) : const Color(0xFFE2F6D5),
                                              borderRadius: BorderRadius.circular(9999),
                                              border: Border.all(
                                                color: isDark ? AppTheme.accentCyan.withOpacity(0.3) : const Color(0xFFC5EDAB),
                                              ),
                                            ),
                                            child: Text(
                                              '$totalCal KCAL',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w900,
                                                color: isDark ? AppTheme.accentCyan : const Color(0xFF054D28),
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),

                                      // Macros splits capsule details
                                      Row(
                                        children: [
                                          _buildMacroTag('Protein', '${protein.round()}g', AppTheme.accentOrange),
                                          const SizedBox(width: 8),
                                          _buildMacroTag('Carbs', '${carbs.round()}g', AppTheme.accentCyan),
                                          const SizedBox(width: 8),
                                          _buildMacroTag('Fats', '${fat.round()}g', AppTheme.accentCoral),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      const Divider(color: AppTheme.glassBorder, height: 1),
                                      const SizedBox(height: 10),

                                      // Itemized Meals Food Feed
                                      if (items.isEmpty)
                                        const Text(
                                          'No meals logged for this day.',
                                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                        )
                                      else
                                        ...items.map((item) {
                                          final name = item['name'] ?? 'Logged Meal';
                                          final calories = item['calories'] ?? 0;
                                          final meal = item['meal'] ?? 'MEAL';
                                          final time = item['time'] ?? '8:00 AM';
                                          
                                          // Pick a relatable food image matching key words
                                          String imgUrl = 'https://lh3.googleusercontent.com/aida-public/AB6AXuCFm2XsMjmJXAwf6NI19eSwHEj0P9zTCPYixIxf-0z0TEcCuUHilYMI3P4tUgUe-PdA9HXvnTLZZ1ndshzFd3I3DnyErcUadkcQJa9YLl1imhnDgQgG5Sze7_tsXER8ycWlX977B9ZhqsctcZIxLZVgAaulUYjOvqimZIh7pOZ4R0Tq-KJeeQ_vAi6NQACiSB_5dxlxijqCH2Smr5IoNorK8wcS2dHSA8j7v2W89G_EGOKHVnmkUg2OhkglDg0MKzwIWAJxCyJJaCQ';
                                          if (name.toString().contains('Toast') || name.toString().contains('Egg')) {
                                            imgUrl = 'https://lh3.googleusercontent.com/aida-public/AB6AXuB2brSlsBgFFmGsip9c_GbksCXBfFKCIgXcey-f5BrJwkkPWEQjC-sUEd1tVxXASMRu__FqDDxIF9MhDwLZ_UCW5XLrEky021sbzy5pb5bQh3ObP3rtU3zoNA0dYNdHPKB1KcM1KgAvTflJikH-Uz8Pkd4w7ZwXidpEHOLubS0bPb_yX6LuQIFmy2TfeRp9iLTjR_BZSV7G44gZ6Ry9IIZiH3jp86HDRnqI_HoYoht8sgs4yTMO4ugB_i6sd0X9f44R7CjTKNqUiiQ';
                                          } else if (name.toString().contains('Chicken') || name.toString().contains('Rice') || name.toString().contains('Steak')) {
                                            imgUrl = 'https://lh3.googleusercontent.com/aida-public/AB6AXuD4gdf3X8OnLsapm-Piw4rPMArGDzOLo7p-gnURZNjggLn2rmRQIqqpNSf6EjXEsUd3dA08wsh92W55i7CbD8kSLNRrJuH63mIq5BKmseO1WDdDPX571SnULDG3XSh9-f9dWXPw5C2E8KjF-h9VCbgmJXTsTHY6dU7_3QXHCty5DG9-5FufNgPt93xmFEdXz-VMh-h6mmpuD87hpUSw-DDrrn3Fhz-JcqZaU_Kh2E3KcqLScTzCoMaPsWqik1DaMNmFSdCQLmwlp38';
                                          }

                                          final String? customImageUrl = item['imageUrl'];
                                          ImageProvider imageProvider;
                                          debugPrint("History Item: $name, imageUrl: ${customImageUrl != null ? (customImageUrl.length > 50 ? '${customImageUrl.substring(0, 50)}...' : customImageUrl) : 'null'}");
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
                                                debugPrint("ERROR DECODING BASE64 FOR $name: $e");
                                                imageProvider = NetworkImage(imgUrl);
                                              }
                                            }
                                          } else {
                                            imageProvider = NetworkImage(imgUrl);
                                          }

                                          return GestureDetector(
                                            onTap: () => _showFoodDetailsDialog(context, ref, dateStr, Map<String, dynamic>.from(item)),
                                            behavior: HitTestBehavior.opaque,
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(vertical: 6.0),
                                              child: Row(
                                                children: [
                                                  // Food avatar
                                                  Container(
                                                    width: 38,
                                                    height: 38,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      image: DecorationImage(
                                                        image: imageProvider,
                                                        fit: BoxFit.cover,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  
                                                  // Food detail texts
                                                   Expanded(
                                                     child: Column(
                                                       crossAxisAlignment: CrossAxisAlignment.start,
                                                       children: [
                                                         Text(
                                                           name,
                                                           style: TextStyle(
                                                             fontWeight: FontWeight.bold,
                                                             fontSize: 13,
                                                             color: isDark ? Colors.white : AppTheme.textPrimary,
                                                           ),
                                                         ),
                                                         const SizedBox(height: 2),
                                                         Text(
                                                           '$meal • $time',
                                                           style: const TextStyle(
                                                             color: AppTheme.textSecondary,
                                                             fontSize: 10,
                                                           ),
                                                         ),
                                                       ],
                                                     ),
                                                   ),
                                                   
                                                   // Calorie tag
                                                   Text(
                                                     '$calories kcal',
                                                     style: TextStyle(
                                                       fontWeight: FontWeight.w900,
                                                       fontSize: 13,
                                                       color: isDark ? AppTheme.accentCyan : const Color(0xFF054D28),
                                                     ),
                                                   ),
                                                ],
                                              ),
                                            ),
                                          );
                                        }),
                                    ],
                                  ),
                                ),
                                  ).animate().fade(duration: 300.ms, delay: (index * 50).ms).slideY(begin: 0.1, end: 0);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroTag(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 4),
          Text(
            '$label: $value',
            style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.restaurant_menu_rounded,
            size: 64,
            color: isDark ? Colors.white.withOpacity(0.15) : Colors.black.withOpacity(0.1),
          ),
          const SizedBox(height: 16),
          const Text(
            'No logged meals in your lifetime history.',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

Future<dynamic> _showFoodDetailsDialog(
  BuildContext context,
  WidgetRef ref,
  String dateStr,
  Map<String, dynamic> item, {
  bool startInEditMode = false,
}) {
  final parsedDate = DateFormat('yyyy-MM-dd').parse(dateStr);
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

  Widget buildMacroCard(String label, String val, Color col, String emoji) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: col.withOpacity(0.06),
        borderRadius: BorderRadius.circular(24),
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
            style: TextStyle(
              color: isDark ? Colors.white : AppTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildMiniEditField(String label, TextEditingController controller, String emoji) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w600, fontSize: 13),
          decoration: InputDecoration(
            hintText: "0",
            hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 12),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 10, right: 6),
              child: Center(
                widthFactor: 1.0,
                child: Text(emoji, style: const TextStyle(fontSize: 16)),
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
    );
  }

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
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
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
                      // Header Row
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
                          style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppTheme.textPrimary),
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
                        const Padding(
                          padding: EdgeInsets.only(left: 4, bottom: 6),
                          child: Text(
                            "Calories",
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                        TextField(
                          controller: calController,
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
                            Expanded(child: buildMiniEditField("Protein", proteinController, '🍗')),
                            const SizedBox(width: 8),
                            Expanded(child: buildMiniEditField("Carbs", carbsController, '🍚')),
                            const SizedBox(width: 8),
                            Expanded(child: buildMiniEditField("Fat", fatController, '🥑')),
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
                                  final currentMetrics = ref.read(dailyMetricsProvider(dateStr));
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

                                    await ref.read(dailyMetricsProvider(dateStr).notifier).saveMetrics(updatedMetrics);

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        backgroundColor: AppTheme.accentCoral,
                                        content: Text("Deleted entry: $initialName"),
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
                                  final currentMetrics = ref.read(dailyMetricsProvider(dateStr));
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

                                    await ref.read(dailyMetricsProvider(dateStr).notifier).saveMetrics(updatedMetrics);

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
