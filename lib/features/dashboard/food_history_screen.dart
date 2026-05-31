import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme.dart';
import '../../services/storage_service.dart';

class FoodHistoryScreen extends ConsumerWidget {
  const FoodHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loggedDates = StorageService.getAllLoggedDates();

    final bgColor = isDark ? AppTheme.obsidianBackground : const Color(0xFFF1F5F9);

    return Scaffold(
      backgroundColor: bgColor,
      body: Container(
        color: bgColor,
        child: Stack(
          children: [
            // Ambient Backdrop Glows (matching Cyber theme)
            if (isDark) ...[
              Positioned(
                top: -60,
                right: -60,
                child: Container(
                  width: 320,
                  height: 320,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.accentCyan.withOpacity(0.06),
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
                    color: AppTheme.accentPurple.withOpacity(0.04),
                  ),
                ).animate(onPlay: (c) => c.repeat(reverse: true))
                    .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 10.seconds, curve: Curves.easeInOut)
                    .custom(builder: (context, val, child) => ImageFiltered(
                          imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                          child: child,
                        )),
              ),
            ],

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
                              
                              final stats = StorageService.getDailyMetrics(dateStr);
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
                                  borderRadius: BorderRadius.circular(20),
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
                                              color: AppTheme.accentCyan.withOpacity(0.08),
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(
                                                color: AppTheme.accentCyan.withOpacity(0.2),
                                              ),
                                            ),
                                            child: Text(
                                              '$totalCal KCAL',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w900,
                                                color: AppTheme.accentCyan,
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

                                          return GestureDetector(
                                            onTap: () => _showFoodDetailsDialog(context, Map<String, dynamic>.from(item)),
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
                                                        image: NetworkImage(imgUrl),
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
                                                          style: const TextStyle(
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 13,
                                                            color: Colors.white,
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
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.w900,
                                                      fontSize: 13,
                                                      color: AppTheme.accentCyan,
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
        borderRadius: BorderRadius.circular(6),
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

void _showFoodDetailsDialog(BuildContext context, Map<String, dynamic> item) {
  final String name = item['name'] ?? 'Logged Meal';
  final String meal = item['meal'] ?? 'MEAL';
  final String time = item['time'] ?? '8:00 AM';
  final int calories = item['calories'] ?? 0;
  final int protein = item['protein'] ?? 0;
  final int carbs = item['carbs'] ?? 0;
  final int fat = item['fat'] ?? 0;

  final isDark = Theme.of(context).brightness == Brightness.dark;

  showDialog(
    context: context,
    builder: (context) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xEC090E18) : Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: isDark ? AppTheme.glassBorder : const Color(0xFFEADBFF),
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row: Close Button & Category
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Glowing Category Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppTheme.accentPurple.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppTheme.accentPurple.withOpacity(0.3),
                            width: 1.2,
                          ),
                        ),
                        child: Text(
                          meal,
                          style: const TextStyle(
                            color: AppTheme.accentPurple,
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                            letterSpacing: 0.8,
                          ),
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

                  // Meal Name
                  Text(
                    name,
                    style: TextStyle(
                      color: isDark ? Colors.white : AppTheme.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Time indicator row
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
                  const SizedBox(height: 24),

                  // Bento-Grid of Nutrients
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
                    decoration: BoxDecoration(
                      color: AppTheme.accentCyan.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppTheme.accentCyan.withOpacity(0.25),
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
                                  'Energy Output',
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
                        Text(
                          '$calories kcal',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Macros Splits
                  Row(
                    children: [
                      // Protein Card
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
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
                              const Icon(
                                  Icons.egg_rounded,
                                  color: AppTheme.accentOrange,
                                  size: 16,
                                ),
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
                              Text(
                                '${protein}g',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Carbs Card
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
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
                              const Icon(
                                  Icons.bakery_dining_rounded,
                                  color: AppTheme.accentCyan,
                                  size: 16,
                                ),
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
                              Text(
                                '${carbs}g',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Fats Card
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
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
                              const Icon(
                                  Icons.water_drop_rounded,
                                  color: AppTheme.accentCoral,
                                  size: 16,
                                ),
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
                              Text(
                                '${fat}g',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
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
}
