import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme.dart';

class VisionLoadingWidget extends StatefulWidget {
  final String title;
  final String subtitle;

  const VisionLoadingWidget({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  State<VisionLoadingWidget> createState() => _VisionLoadingWidgetState();
}

class _VisionLoadingWidgetState extends State<VisionLoadingWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _laserController;

  @override
  void initState() {
    super.initState();
    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _laserController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : AppTheme.textPrimary;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.accentCyan.withOpacity(0.04),
                  border: Border.all(
                    color: AppTheme.accentCyan.withOpacity(0.2),
                    width: 1,
                  ),
                ),
              )
                  .animate(onPlay: (controller) => controller.repeat())
                  .scale(
                    begin: const Offset(0.9, 0.9),
                    end: const Offset(1.1, 1.1),
                    duration: 1200.ms,
                    curve: Curves.easeInOut,
                  )
                  .fadeOut(duration: 1200.ms),
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: AppTheme.glassBackground,
                  border: Border.all(
                    color: AppTheme.accentCyan.withOpacity(0.4),
                    width: 1.0,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.center_focus_weak_rounded,
                    color: AppTheme.accentCyan,
                    size: 44,
                  ),
                ),
              ),
              AnimatedBuilder(
                animation: _laserController,
                builder: (context, child) {
                  return Positioned(
                    top: 20 + (_laserController.value * 60),
                    left: 20,
                    right: 20,
                    child: Container(
                      height: 2,
                      decoration: const BoxDecoration(
                        color: AppTheme.accentCyan,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 32),
          Text(
            widget.title,
            style: TextStyle(
              color: primaryTextColor,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.3,
            ),
          ).animate().fadeIn(duration: 300.ms),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: Text(
              widget.subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ).animate().fadeIn(delay: 150.ms, duration: 300.ms),
        ],
      ),
    );
  }
}
