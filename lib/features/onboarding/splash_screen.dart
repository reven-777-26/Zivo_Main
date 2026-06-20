import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
    final bgColor = isDark ? const Color(0xFF141618) : AppTheme.obsidianBackground;

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // Background ambient gradient glow
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.2,
                  colors: [
                    const Color(0xFFD2FB10).withOpacity(0.04),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // SVG Logo from assets with entry and looping pulse animations
                SvgPicture.asset(
                  'assets/Logo.svg',
                  width: 140,
                  height: 140,
                )
                .animate()
                .fadeIn(duration: 1000.ms)
                .scale(
                  begin: const Offset(0.5, 0.5),
                  curve: Curves.easeOutBack,
                  duration: 1000.ms,
                )
                .then(delay: 200.ms)
                .shimmer(duration: 1200.ms, color: const Color(0xFFD2FB10).withOpacity(0.4))
                .animate(onPlay: (controller) => controller.repeat(reverse: true))
                .scale(
                  begin: const Offset(1, 1),
                  end: const Offset(1.05, 1.05),
                  duration: 2000.ms,
                  curve: Curves.easeInOut,
                ),
                const SizedBox(height: 48),
                
                // Tagline styled with a premium glassmorphic neon glow pill and repeating shimmer loop
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.02),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: const Color(0xFFD2FB10).withOpacity(0.18),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD2FB10).withOpacity(0.03),
                        blurRadius: 20,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [
                        Colors.white,
                        Color(0xFFD2FB10),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ).createShader(bounds),
                    child: const Text(
                      'TRACK SMARTER. LIVE BETTER.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Outfit',
                        color: Colors.white,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                )
                .animate()
                .fadeIn(delay: 500.ms, duration: 800.ms)
                .slideY(begin: 0.3, end: 0, curve: Curves.easeOutCubic)
                .animate(onPlay: (controller) => controller.repeat())
                .shimmer(delay: 2000.ms, duration: 1500.ms, color: const Color(0xFFD2FB10).withOpacity(0.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
