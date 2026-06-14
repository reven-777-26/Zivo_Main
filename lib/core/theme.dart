import 'dart:ui';
import 'package:flutter/material.dart';

class AppTheme {
  // Wise Design System Color Palette
  static const Color obsidianBackground = Color(0xFFE8EBE6); // Canvas Soft (Sage)
  static const Color glassBackground = Color(0xFFFFFFFF); // Canvas (White)
  static const Color glassBorder = Color(0xFFE8EBE6); // Muted sage border

  static const Color accentEmerald = Color(0xFF2EAD4B); // Positive Green
  static const Color accentCyan = Color(0xFFCDF200); // ZivoFit Neon Lime (Primary Accent)
  static const Color accentCoral = Color(0xFFD03238); // Negative Red
  static const Color accentOrange = Color(0xFFFFC091); // Accent Peach Orange
  static const Color accentPurple = Color(0xFFCDF200); // ZivoFit Neon Lime

  static const Color textPrimary = Color(0xFF0E0F0C); // Ink Black
  static const Color textSecondary = Color(0xFF868685); // Body Text / Mute Text
  static const Color textTertiary = Color(0xFF868685); // Mute Text

  // Flat linear gradients to comply with "no decorative gradients" rule
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [accentCyan, accentCyan],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient coralGradient = LinearGradient(
    colors: [accentCoral, accentCoral],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient purpleGradient = LinearGradient(
    colors: [accentCyan, accentCyan],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient bgGradient = LinearGradient(
    colors: [obsidianBackground, obsidianBackground],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static ThemeData get lightTheme {
    return ThemeData.light().copyWith(
      scaffoldBackgroundColor: obsidianBackground,
      cardColor: glassBackground,
      dividerColor: const Color(0xFFE8EBE6),
      colorScheme: const ColorScheme.light().copyWith(
        primary: accentCyan,
        secondary: accentPurple,
        surface: glassBackground,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: textPrimary,
          fontSize: 32,
          fontWeight: FontWeight.w900, // Wise Sans heavy display weight
          letterSpacing: -0.8,
        ),
        headlineMedium: TextStyle(
          color: textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.6,
        ),
        titleLarge: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.3,
        ),
        bodyLarge: TextStyle(
          color: textSecondary,
          fontSize: 16,
          fontWeight: FontWeight.normal,
        ),
        bodyMedium: TextStyle(
          color: textTertiary,
          fontSize: 14,
          fontWeight: FontWeight.normal,
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: const Color(0xFF000000), // AMOLED Pure Black
      cardColor: const Color(0xFF1C1C1E), // ZivoFit Level 1 card surface
      dividerColor: const Color(0xFF2C2C2E), // ZivoFit Level 2 interactive boundary
      colorScheme: const ColorScheme.dark().copyWith(
        primary: accentCyan,
        secondary: accentPurple,
        surface: const Color(0xFF1C1C1E),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: Color(0xFFE8EBE6),
          fontSize: 32,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.8,
        ),
        headlineMedium: TextStyle(
          color: Color(0xFFE8EBE6),
          fontSize: 24,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.6,
        ),
        titleLarge: TextStyle(
          color: Color(0xFFE8EBE6),
          fontSize: 20,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.3,
        ),
        bodyLarge: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.normal,
        ),
        bodyMedium: TextStyle(
          color: Color(0xFF868685),
          fontSize: 14,
          fontWeight: FontWeight.normal,
        ),
      ),
    );
  }
}

class GlassCard extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadiusGeometry? borderRadius;
  final LinearGradient? borderGradient;
  final Color? customBgColor;
  final Border? customBorder;
  final bool enableBlur;

  const GlassCard({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.borderRadius,
    this.borderGradient,
    this.customBgColor,
    this.customBorder,
    this.enableBlur = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveRadius = borderRadius ?? BorderRadius.circular(24); // Default 24px (rounded.xl)

    final cardBgColor =
        customBgColor ??
        (isDark ? const Color(0xFF1C1C1E) : AppTheme.glassBackground);
    final cardBorderColor = isDark
        ? const Color(0xFF2C2C2E)
        : AppTheme.glassBorder;

    Widget cardContent = Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: effectiveRadius,
        border: customBorder ?? Border.all(color: cardBorderColor, width: 1.0),
      ),
      child: child,
    );

    if (enableBlur) {
      return Container(
        margin: margin,
        child: ClipRRect(
          borderRadius: effectiveRadius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: cardContent,
          ),
        ),
      );
    }

    return Container(margin: margin, child: cardContent);
  }
}
