import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ZivoLogoWidget extends StatelessWidget {
  final double size;
  final Color color;

  const ZivoLogoWidget({
    super.key,
    required this.size,
    this.color = const Color(0xFFD9FF00),
  });

  @override
  Widget build(BuildContext context) {
    // The Logo.svg viewBox is 85 195 347 121 (width 347, height 121)
    // To prevent empty vertical padding inside the square container, 
    // we set the height matching the aspect ratio (121 / 347 ≈ 0.348)
    return SvgPicture.asset(
      'assets/Logo.svg',
      width: size,
      height: size * (121 / 347),
      fit: BoxFit.contain,
    );
  }
}
