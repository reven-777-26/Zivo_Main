import 'package:flutter/material.dart';

class ZivoLogoWidget extends StatelessWidget {
  final double size;
  final Color color;

  const ZivoLogoWidget({
    super.key,
    required this.size,
    this.color = const Color(0xFFD9FF00), // Zivo brand neon lime-yellow
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _ZivoLogoPainter(color: color),
    );
  }
}

class _ZivoLogoPainter extends CustomPainter {
  final Color color;

  _ZivoLogoPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.1
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - paint.strokeWidth) / 2;

    // Draw incomplete circle (open on the right side)
    // Angles in radians: 0 is right (3 o'clock), pi/2 is down (6 o'clock)
    // Gap from -35 degrees to 35 degrees. Start angle is 35 deg (0.61 rad).
    // Sweep angle is 290 deg (5.06 rad).
    const startAngle = 0.61;
    const sweepAngle = 5.06;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      paint,
    );

    // Draw the rounded "Z" shape inside the circle
    final zPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.1
      ..strokeCap = StrokeCap.round;

    final double padding = size.width * 0.28;
    final double left = padding;
    final double right = size.width - padding;
    final double top = padding;
    final double bottom = size.height - padding;

    final path = Path()
      ..moveTo(left, top)
      ..lineTo(right, top)
      ..lineTo(left, bottom)
      ..lineTo(right, bottom);

    canvas.drawPath(path, zPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
