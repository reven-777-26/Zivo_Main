import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../core/logo_widget.dart';
import '../../services/state_providers.dart';
import '../../services/firebase_service.dart';
import '../../services/storage_service.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToNext();
  }

  Future<void> _navigateToNext() async {
    await Future.delayed(const Duration(milliseconds: 2000));
    if (!mounted) return;

    final isLoggedIn = FirebaseService.isLoggedIn;
    if (isLoggedIn) {
      final profile = ref.read(profileProvider);
      if (profile == null) {
        // Fetch profile and other data from cloud if missing locally
        await FirebaseService.syncCloudToLocal();
        if (mounted) {
          ref.invalidate(profileProvider);
          ref.invalidate(workoutHistoryProvider);
          ref.invalidate(pinnedWidgetsProvider);
          ref.invalidate(remindersProvider);
          ref.invalidate(profilePictureProvider);
          ref.invalidate(customBackgroundProvider);
        }
      } else {
        // Silently sync from cloud in background to keep data fresh
        FirebaseService.syncCloudToLocal().then((_) {
          if (mounted) {
            ref.invalidate(profileProvider);
            ref.invalidate(workoutHistoryProvider);
            ref.invalidate(pinnedWidgetsProvider);
            ref.invalidate(remindersProvider);
            ref.invalidate(profilePictureProvider);
            ref.invalidate(customBackgroundProvider);
          }
        });
      }

      // Read updated profile state
      final updatedProfile = StorageService.getUserProfile();
      if (!mounted) return;
      if (updatedProfile != null) {
        context.go('/home');
      } else {
        context.go('/onboarding');
      }
    } else {
      if (!mounted) return;
      context.go('/auth');
    }
  }
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? const Color(0xFFE8EBE6) : AppTheme.textPrimary;
    final bgColor = isDark ? const Color(0xFF0E0F0C) : AppTheme.obsidianBackground;

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Zivo circular-Z logo
                const ZivoLogoWidget(size: 80)
                .animate()
                .fadeIn(duration: 800.ms)
                .scale(
                  begin: const Offset(0.7, 0.7),
                  curve: Curves.easeOutBack,
                  duration: 800.ms,
                ),
                const SizedBox(height: 32),
                
                // App Title (ZivoFit) in Heavy Display Weight
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Outfit',
                      letterSpacing: -0.8,
                    ),
                    children: [
                      TextSpan(
                        text: 'Zivo',
                        style: TextStyle(color: textColor),
                      ),
                      TextSpan(
                        text: 'Fit',
                        style: const TextStyle(color: Color(0xFFD9FF00)),
                      ),
                    ],
                  ),
                )
                .animate()
                .fadeIn(delay: 200.ms, duration: 600.ms)
                .slideY(begin: 0.15, end: 0, curve: Curves.easeOutCubic),
                const SizedBox(height: 12),
                
                // App Subtitle
                Text(
                  'Track Smarter. Live Better.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppTheme.textTertiary : const Color(0xFF868685),
                    letterSpacing: 0.196,
                  ),
                )
                .animate()
                .fadeIn(delay: 400.ms, duration: 600.ms)
                .slideY(begin: 0.15, end: 0, curve: Curves.easeOutCubic),
              ],
            ),
          ),

          // Loading spinner at the bottom
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 64.0),
              child: SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppTheme.accentCyan,
                  ),
                ),
              ),
            ),
          ).animate().fadeIn(delay: 600.ms),
        ],
      ),
    );
  }
}
