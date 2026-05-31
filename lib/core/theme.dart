import 'dart:ui';
import 'package:flutter/material.dart';

class AppTheme {
  // Brand New Color Palette: Premium Refreshing Spring Spruce & Ocean Mint
  static const Color obsidianBackground = Color(0xFF04100E); // Refreshing Spruce Deep Black
  static const Color glassBackground = Color(0xFF0D2521); // Rich Spruce Dark Mint
  static const Color glassBorder = Color(0xFF163E35); // Frosty Mint Spruce Border

  static const Color accentEmerald = Color(0xFF10B981); // Crisp Active Emerald Mint
  static const Color accentCyan = Color(0xFF20E682); // High-Contrast Cyber Mint Green
  static const Color accentCoral = Color(0xFFFF5E7E); // Vibrant Rose Coral
  static const Color accentOrange = Color(0xFFFBBF24); // Sunrise Gold Amber
  static const Color accentPurple = Color(0xFF06B6D4); // Ocean Ice Cyan

  static const Color textPrimary = Color(0xFFF0FDF4); // Mint Cream White
  static const Color textSecondary = Color(0xFF86A39F); // Muted Sage Slate
  static const Color textTertiary = Color(0xFF1D3531); // Deep Charcoal Spruce

  // Solid flat gradients to retain compile safety while completely eliminating gradients
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
    colors: [accentPurple, accentPurple],
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
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF1F5F9),
      cardColor: const Color(0xFFFFFFFF),
      dividerColor: const Color(0xFFE2E8F0),
      colorScheme: const ColorScheme.light().copyWith(
        primary: accentCyan,
        secondary: accentPurple,
        surface: const Color(0xFFFFFFFF),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: Color(0xFF0F172A),
          fontSize: 32,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.8,
        ),
        headlineMedium: TextStyle(
          color: Color(0xFF0F172A),
          fontSize: 24,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.6,
        ),
        titleLarge: TextStyle(
          color: Color(0xFF0F172A),
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        bodyLarge: TextStyle(
          color: Color(0xFF0F172A),
          fontSize: 16,
          fontWeight: FontWeight.normal,
        ),
        bodyMedium: TextStyle(
          color: Color(0xFF475569),
          fontSize: 14,
          fontWeight: FontWeight.normal,
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData.dark().copyWith(
      useMaterial3: true,
      scaffoldBackgroundColor: obsidianBackground,
      cardColor: glassBackground,
      dividerColor: glassBorder,
      colorScheme: const ColorScheme.dark().copyWith(
        primary: accentCyan,
        secondary: accentPurple,
        surface: glassBackground,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: textPrimary,
          fontSize: 32,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.8,
        ),
        headlineMedium: TextStyle(
          color: textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.6,
        ),
        titleLarge: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        bodyLarge: TextStyle(
          color: textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.normal,
        ),
        bodyMedium: TextStyle(
          color: textSecondary,
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
    this.enableBlur = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveRadius = borderRadius ?? BorderRadius.circular(24);

    final cardBgColor =
        customBgColor ??
        (isDark ? AppTheme.glassBackground : const Color(0xFFFFFFFF));
    final cardBorderColor = isDark
        ? AppTheme.glassBorder
        : const Color(0xFFCFD8DC);
    final cardShadowColor = isDark
        ? Colors.black.withOpacity(0.4)
        : Colors.black.withOpacity(0.04);

    Widget cardContent = Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: effectiveRadius,
        border: customBorder ?? Border.all(color: cardBorderColor, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: cardShadowColor,
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );

    if (enableBlur) {
      return Container(
        margin: margin,
        child: ClipRRect(
          borderRadius: effectiveRadius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: cardContent,
          ),
        ),
      );
    }

    return Container(margin: margin, child: cardContent);
  }
}
