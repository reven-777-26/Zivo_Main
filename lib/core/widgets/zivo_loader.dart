import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme.dart';

// ─── Style 0=Morph 1=Orbit 2=Sonar 3=Flow 4=Beat 5=Spin 6=DNA 7=Dots ───────
enum ZivoLoaderStyle { morph, orbit, sonar, flow, beat, spin, dna, dots }

// ─── Widget ───────────────────────────────────────────────────────────────────
class ZivoLoader extends StatefulWidget {
  final double size;
  final Color? color;
  final double strokeWidth;
  final int style; // 0-7

  const ZivoLoader({
    super.key,
    this.size = 40.0,
    this.color,
    this.strokeWidth = 2.0,
    this.style = 0,
  });

  @override
  State<ZivoLoader> createState() => _ZivoLoaderState();
}

class _ZivoLoaderState extends State<ZivoLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  // Duration per style in ms (0-18)
  static const _ms = [
    5500, // 0 Morph
    2800, // 1 Orbit
    2000, // 2 Sonar
    2800, // 3 Flow
    1000, // 4 Beat
    1400, // 5 Spin
    2400, // 6 DNA
    1100, // 7 Dots
    1800, // 8 Wave
    4500, // 9 Clock
    2800, // 10 Spiral
    2800, // 11 Atom
    1800, // 12 Ripple
    400,  // 13 Bounce (fast)
    280,  // 14 Spark (fast)
    260,  // 15 Glitch (fast)
    4500, // 16 Lotus (slow)
    1500, // 17 Ring (medium)
    2200, // 18 Cube (medium)
  ];

  int get _s => widget.style.clamp(0, 18);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _ms[_s]),
    )..repeat();
  }

  @override
  void didUpdateWidget(ZivoLoader old) {
    super.didUpdateWidget(old);
    if (old.style != widget.style) {
      _ctrl.stop();
      _ctrl.duration = Duration(milliseconds: _ms[_s]);
      _ctrl.repeat();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color =
        widget.color ?? (isDark ? const Color(0xFFD9FF00) : AppTheme.accentCyan);

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          final t = _ctrl.value;
          final CustomPainter p;
          if (_s == 1) {
            p = _OrbitPainter(t: t, color: color);
          } else if (_s == 2) {
            p = _SonarPainter(t: t, color: color);
          } else if (_s == 3) {
            p = _FlowPainter(t: t, color: color);
          } else if (_s == 4) {
            p = _BeatPainter(t: t, color: color);
          } else if (_s == 5) {
            p = _SpinPainter(t: t, color: color, sw: widget.strokeWidth);
          } else if (_s == 6) {
            p = _DNAPainter(t: t, color: color);
          } else if (_s == 7) {
            p = _DotsPainter(t: t, color: color);
          } else if (_s == 8) {
            p = _WavePainter(t: t, color: color);
          } else if (_s == 9) {
            p = _ClockPainter(t: t, color: color);
          } else if (_s == 10) {
            p = _SpiralPainter(t: t, color: color);
          } else if (_s == 11) {
            p = _AtomPainter(t: t, color: color);
          } else if (_s == 12) {
            p = _RipplePainter(t: t, color: color);
          } else if (_s == 13) {
            p = _BouncePainter(t: t, color: color);
          } else if (_s == 14) {
            p = _SparkPainter(t: t, color: color);
          } else if (_s == 15) {
            p = _GlitchPainter(t: t, color: color);
          } else if (_s == 16) {
            p = _LotusPainter(t: t, color: color);
          } else if (_s == 17) {
            p = _RingPainter(t: t, color: color);
          } else if (_s == 18) {
            p = _CubePainter(t: t, color: color);
          } else {
            p = _MorphPainter(t: t, primary: color, isDark: isDark);
          }
          return CustomPaint(painter: p);
        },
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// SHARED HELPERS
// ────────────────────────────────────────────────────────────────────────────

double _ease(double x) {
  x = x.clamp(0.0, 1.0);
  return x * x * (3.0 - 2.0 * x);
}

/// Evenly distribute [n] points around a regular [sides]-polygon.
List<Offset> _polygon(int sides, int n, double r, double cx, double cy,
    double rotation) {
  return List.generate(n, (i) {
    final f = i / n;
    final seg = (f * sides).floor();
    final frac = (f * sides) % 1.0;
    final a1 = 2 * math.pi * seg / sides + rotation;
    final a2 = 2 * math.pi * (seg + 1) / sides + rotation;
    final x1 = cx + r * math.cos(a1);
    final y1 = cy + r * math.sin(a1);
    final x2 = cx + r * math.cos(a2);
    final y2 = cy + r * math.sin(a2);
    return Offset(x1 + frac * (x2 - x1), y1 + frac * (y2 - y1));
  });
}

/// [n] evenly spaced points around a circle, starting from the top.
List<Offset> _circle(int n, double r, double cx, double cy) {
  return List.generate(n, (i) {
    final a = i * 2 * math.pi / n - math.pi / 2;
    return Offset(cx + r * math.cos(a), cy + r * math.sin(a));
  });
}

/// Distribute [n] points around a [points]-pointed star (alternating outer/inner).
List<Offset> _star(int n, int points, double outerR, double innerR,
    double cx, double cy) {
  final vc = points * 2;
  final verts = List.generate(vc, (j) {
    final r = j.isEven ? outerR : innerR;
    final a = j * math.pi / points - math.pi / 2;
    return Offset(cx + r * math.cos(a), cy + r * math.sin(a));
  });
  return List.generate(n, (i) {
    final f = i / n;
    final seg = (f * vc).floor();
    final frac = (f * vc) % 1.0;
    final p1 = verts[seg % vc];
    final p2 = verts[(seg + 1) % vc];
    return Offset(
        p1.dx + frac * (p2.dx - p1.dx), p1.dy + frac * (p2.dy - p1.dy));
  });
}

/// Linear-lerp between two equal-length point lists.
List<Offset> _lerpPts(List<Offset> a, List<Offset> b, double t) {
  return List.generate(
      a.length,
      (i) =>
          Offset(a[i].dx + t * (b[i].dx - a[i].dx),
                 a[i].dy + t * (b[i].dy - a[i].dy)));
}

Path _pts2path(List<Offset> pts) {
  final p = Path()..moveTo(pts[0].dx, pts[0].dy);
  for (int i = 1; i < pts.length; i++) {
    p.lineTo(pts[i].dx, pts[i].dy);
  }
  return p..close();
}

// ────────────────────────────────────────────────────────────────────────────
// STYLE 0 · MORPH  — cycles circle → triangle → diamond → hexagon → star → circle
// ────────────────────────────────────────────────────────────────────────────
class _MorphPainter extends CustomPainter {
  final double t;
  final Color primary;
  final bool isDark;

  const _MorphPainter(
      {required this.t, required this.primary, required this.isDark});

  static const _n = 60; // points per shape

  // 5 shapes → 5 phases (each 1/5 of total cycle)
  List<Offset> _shape(Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.39;

    final shapes = [
      _circle(_n, r, cx, cy),                          // 0 circle
      _polygon(3, _n, r, cx, cy, -math.pi / 2),        // 1 triangle (point up)
      _polygon(4, _n, r * 0.82, cx, cy, 0),            // 2 diamond (rotated sq)
      _polygon(6, _n, r, cx, cy, -math.pi / 2),        // 3 hexagon (flat top)
      _star(_n, 5, r, r * 0.40, cx, cy),               // 4 5-pointed star
    ];

    const phases = 5;
    final phaseF = t * phases;
    final phase = phaseF.floor() % phases;
    final frac = _ease(phaseF % 1.0);
    return _lerpPts(shapes[phase], shapes[(phase + 1) % phases], frac);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final pts = _shape(size);
    final path = _pts2path(pts);
    final rect = Offset.zero & size;

    final pulse = 0.55 + 0.45 * math.sin(t * 2 * math.pi);
    final sec = Color.lerp(
      isDark ? const Color(0xFF00FFB3) : const Color(0xFF2EAD4B),
      isDark ? const Color(0xFFFFD700) : const Color(0xFFFF8C00),
      math.sin(t * math.pi).abs(),
    )!;

    // Glow
    canvas.drawPath(path, Paint()
      ..color = primary.withOpacity(0.28 * pulse)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.13));

    // Fill
    canvas.drawPath(path, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          primary.withOpacity(isDark ? 0.88 : 0.72),
          sec.withOpacity(isDark ? 0.62 : 0.48),
        ],
      ).createShader(rect));

    // Stroke
    canvas.drawPath(path, Paint()
      ..color = primary.withOpacity(0.95)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round);

    // Shimmer
    final r = size.width * 0.39;
    canvas.drawCircle(
      Offset(size.width / 2 - r * 0.28, size.height / 2 - r * 0.28),
      size.width * 0.07,
      Paint()
        ..color = Colors.white.withOpacity(0.50)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
  }

  @override
  bool shouldRepaint(covariant _MorphPainter old) =>
      old.t != t || old.primary != primary;
}

// ────────────────────────────────────────────────────────────────────────────
// STYLE 1 · ORBIT  — 3 dots, integer-multiple speeds → seamless loop
// ────────────────────────────────────────────────────────────────────────────
class _OrbitPainter extends CustomPainter {
  final double t;
  final Color color;

  const _OrbitPainter({required this.t, required this.color});

  // Speeds are integers so all dots return to start at t=1 → seamless loop.
  // (radius_fraction, speed_int, initial_phase, dot_radius_fraction)
  static const _orbits = [
    (r: 0.38, spd: 1,  ph: 0.0,            dr: 0.085),
    (r: 0.23, spd: -2, ph: math.pi,        dr: 0.060),
    (r: 0.11, spd: 3,  ph: math.pi / 2,    dr: 0.042),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final cx = size.width / 2;
    final cy = size.height / 2;

    for (final o in _orbits) {
      final wr = size.width * o.r;   // world radius
      final wdr = size.width * o.dr; // world dot-radius
      final angle = t * 2 * math.pi * o.spd + o.ph;

      // Trail — 28 steps, each stepping back 0.012 in normalised time.
      // For integer speed N, N steps of 1/N each wraps exactly, so trail
      // always stays on the correct arc. Seamless!
      const steps = 28;
      for (int i = steps; i >= 1; i--) {
        final ta = (t - i * 0.012) * 2 * math.pi * o.spd + o.ph;
        final frac = 1 - i / steps;
        canvas.drawCircle(
          Offset(cx + wr * math.cos(ta), cy + wr * math.sin(ta)),
          wdr * (0.22 + 0.78 * frac),
          Paint()..color = color.withOpacity(frac * 0.65),
        );
      }

      // Glow halo
      canvas.drawCircle(
        Offset(cx + wr * math.cos(angle), cy + wr * math.sin(angle)),
        wdr * 2.0,
        Paint()
          ..color = color.withOpacity(0.26)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, wdr * 1.3),
      );
      // Solid dot
      canvas.drawCircle(
        Offset(cx + wr * math.cos(angle), cy + wr * math.sin(angle)),
        wdr,
        Paint()..color = color,
      );
    }

    // Pulsing centre
    final pr = size.width * 0.052 * (0.7 + 0.3 * math.sin(t * 6 * math.pi));
    canvas.drawCircle(Offset(cx, cy), pr, Paint()
      ..color = color.withOpacity(0.72)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
  }

  @override
  bool shouldRepaint(covariant _OrbitPainter old) => old.t != t;
}

// ────────────────────────────────────────────────────────────────────────────
// STYLE 2 · SONAR  — expanding pulse rings from centre
// ────────────────────────────────────────────────────────────────────────────
class _SonarPainter extends CustomPainter {
  final double t;
  final Color color;

  const _SonarPainter({required this.t, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final c = Offset(size.width / 2, size.height / 2);
    final maxR = size.width * 0.44;

    for (int i = 0; i < 3; i++) {
      final rt = (t + i / 3.0) % 1.0;
      final r = rt * maxR;
      final op = (1 - rt) * 0.90;
      final sw = (1.0 - rt * 0.5) * 2.0;
      canvas.drawCircle(c, r, Paint()
        ..color = color.withOpacity(op * 0.40)
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw * 3
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, sw * 2));
      canvas.drawCircle(c, r, Paint()
        ..color = color.withOpacity(op)
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw);
    }

    final pulse = 0.6 + 0.4 * math.sin(t * 6 * math.pi);
    canvas.drawCircle(c, size.width * 0.085 * pulse, Paint()
      ..color = color.withOpacity(0.85)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    canvas.drawCircle(c, size.width * 0.048 * pulse,
        Paint()..color = Colors.white.withOpacity(0.90));
  }

  @override
  bool shouldRepaint(covariant _SonarPainter old) => old.t != t;
}

// ────────────────────────────────────────────────────────────────────────────
// STYLE 3 · FLOW  — glowing dot on Lissajous 2:1 figure-8 with comet tail
// ────────────────────────────────────────────────────────────────────────────
class _FlowPainter extends CustomPainter {
  final double t;
  final Color color;

  const _FlowPainter({required this.t, required this.color});

  static Offset _pt(double frac, double rx, double ry, double cx, double cy) {
    final a = frac * 2 * math.pi;
    return Offset(cx + rx * math.sin(2 * a), cy + ry * math.sin(a));
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final rx = size.width * 0.40;
    final ry = size.height * 0.30;

    // Faint guide
    final guide = Path();
    for (int i = 0; i <= 240; i++) {
      final p = _pt(i / 240.0, rx, ry, cx, cy);
      if (i == 0) guide.moveTo(p.dx, p.dy); else guide.lineTo(p.dx, p.dy);
    }
    guide.close();
    canvas.drawPath(guide, Paint()
      ..color = color.withOpacity(0.09)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeJoin = StrokeJoin.round);

    // Comet tail
    const trailSteps = 32;
    for (int i = trailSteps; i >= 1; i--) {
      final frac = 1 - i / trailSteps;
      final p = _pt(t - i * 0.011, rx, ry, cx, cy);
      canvas.drawCircle(p, size.width * 0.06 * frac,
          Paint()..color = color.withOpacity(frac * 0.75));
    }

    // Leading dot
    final head = _pt(t, rx, ry, cx, cy);
    canvas.drawCircle(head, size.width * 0.075, Paint()
      ..color = color.withOpacity(0.50)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    canvas.drawCircle(head, size.width * 0.058, Paint()..color = color);
    canvas.drawCircle(
        head, size.width * 0.032, Paint()..color = Colors.white.withOpacity(0.90));
  }

  @override
  bool shouldRepaint(covariant _FlowPainter old) => old.t != t;
}

// ────────────────────────────────────────────────────────────────────────────
// STYLE 4 · BEAT  — 4 equaliser bars bouncing with neon glow
// ────────────────────────────────────────────────────────────────────────────
class _BeatPainter extends CustomPainter {
  final double t;
  final Color color;

  const _BeatPainter({required this.t, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    const n = 4;
    final bw = size.width * 0.14;
    final gap = size.width * 0.072;
    final totalW = n * bw + (n - 1) * gap;
    final x0 = (size.width - totalW) / 2;
    final phases = [0.0, math.pi * 0.55, math.pi * 1.1, math.pi * 1.65];

    for (int i = 0; i < n; i++) {
      final hf = 0.22 + 0.68 * (0.5 + 0.5 * math.sin(t * 2 * math.pi + phases[i]));
      final bh = size.height * hf;
      final x = x0 + i * (bw + gap);
      final y = (size.height - bh) / 2;
      final rect = Rect.fromLTWH(x, y, bw, bh);
      final rr = RRect.fromRectAndRadius(rect, Radius.circular(bw / 2));
      canvas.drawRRect(rr, Paint()
        ..color = color.withOpacity(0.38)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
      canvas.drawRRect(rr, Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color, color.withOpacity(0.50)],
        ).createShader(rect));
    }
  }

  @override
  bool shouldRepaint(covariant _BeatPainter old) => old.t != t;
}

// ────────────────────────────────────────────────────────────────────────────
// STYLE 5 · SPIN  — sweeping glowing arc (premium spinner)
// ────────────────────────────────────────────────────────────────────────────
class _SpinPainter extends CustomPainter {
  final double t;
  final Color color;
  final double sw; // stroke width

  const _SpinPainter({required this.t, required this.color, required this.sw});

  static const double _sweep = 240 * math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - sw;

    // Background track
    canvas.drawCircle(center, radius, Paint()
      ..color = color.withOpacity(0.08)
      ..strokeWidth = sw * 0.7
      ..style = PaintingStyle.stroke);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(t * 2 * math.pi);

    final arcRect = Rect.fromCircle(center: Offset.zero, radius: radius);

    // Outer neon glow
    canvas.drawArc(arcRect, -math.pi / 2 - _sweep, _sweep, false, Paint()
      ..shader = SweepGradient(
        startAngle: -math.pi / 2 - _sweep,
        endAngle: -math.pi / 2,
        colors: [color.withOpacity(0.0), color.withOpacity(0.55)],
      ).createShader(arcRect)
      ..strokeWidth = sw * 3.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, sw * 2.0));

    // Sharp arc
    canvas.drawArc(arcRect, -math.pi / 2 - _sweep, _sweep, false, Paint()
      ..shader = SweepGradient(
        startAngle: -math.pi / 2 - _sweep,
        endAngle: -math.pi / 2,
        colors: [color.withOpacity(0.0), color],
      ).createShader(arcRect)
      ..strokeWidth = sw
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke);

    // Tip dot
    final tipX = radius * math.cos(-math.pi / 2);
    final tipY = radius * math.sin(-math.pi / 2);
    canvas.drawCircle(Offset(tipX, tipY), sw * 2.2, Paint()
      ..color = color.withOpacity(0.50)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, sw * 2));
    canvas.drawCircle(Offset(tipX, tipY), sw * 1.0,
        Paint()..color = Colors.white);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SpinPainter old) => old.t != t;
}

// ────────────────────────────────────────────────────────────────────────────
// STYLE 6 · DNA  — double helix with depth-sorted dots and connecting rungs
// ────────────────────────────────────────────────────────────────────────────
class _DNAPainter extends CustomPainter {
  final double t;
  final Color color;

  const _DNAPainter({required this.t, required this.color});

  static const _ndots = 7;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final cy = size.height / 2;
    final amp = size.height * 0.32;
    final baseR = size.width * 0.075;
    final span = size.width * 0.88;
    final x0 = size.width * 0.06;
    final scroll = t * 2 * math.pi;

    // Rung lines (behind dots)
    for (int i = 0; i < _ndots; i++) {
      final x = x0 + i * span / (_ndots - 1);
      final phi = i * 2 * math.pi / (_ndots - 1) - scroll;
      final yA = cy + amp * math.sin(phi);
      final yB = cy + amp * math.sin(phi + math.pi);
      canvas.drawLine(Offset(x, yA), Offset(x, yB), Paint()
        ..color = color.withOpacity(0.18)
        ..strokeWidth = 1.2);
    }

    // Collect all dots with depth info
    final dotList = <({Offset pos, double depth})>[];
    for (int i = 0; i < _ndots; i++) {
      final x = x0 + i * span / (_ndots - 1);
      final phi = i * 2 * math.pi / (_ndots - 1) - scroll;
      dotList.add((pos: Offset(x, cy + amp * math.sin(phi)),
                   depth: math.sin(phi)));
      dotList.add((pos: Offset(x, cy + amp * math.sin(phi + math.pi)),
                   depth: math.sin(phi + math.pi)));
    }

    // Back-to-front draw order
    dotList.sort((a, b) => a.depth.compareTo(b.depth));

    for (final d in dotList) {
      final sc = 0.50 + 0.50 * ((d.depth + 1) / 2); // 0.5..1.0
      final op = 0.40 + 0.60 * ((d.depth + 1) / 2);
      final r = baseR * sc;
      canvas.drawCircle(d.pos, r * 1.8, Paint()
        ..color = color.withOpacity(op * 0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 1.2));
      canvas.drawCircle(d.pos, r, Paint()..color = color.withOpacity(op));
      if (d.depth > 0.3) {
        canvas.drawCircle(
            Offset(d.pos.dx - r * 0.30, d.pos.dy - r * 0.30),
            r * 0.30,
            Paint()..color = Colors.white.withOpacity(0.65 * d.depth));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DNAPainter old) => old.t != t;
}

// ────────────────────────────────────────────────────────────────────────────
// STYLE 7 · DOTS  — 3 neon dots bouncing with staggered phase + glow shadow
// ────────────────────────────────────────────────────────────────────────────
class _DotsPainter extends CustomPainter {
  final double t;
  final Color color;

  const _DotsPainter({required this.t, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final cy = size.height / 2;
    final r = size.width * 0.115;
    final amp = size.height * 0.25;
    final shadowY = cy + amp + r * 0.5;

    for (int i = 0; i < 3; i++) {
      final phase = i * 2 * math.pi / 3;
      final bounce = math.sin(t * 2 * math.pi + phase);
      final x = size.width * (0.22 + i * 0.28);
      final y = cy - bounce * amp;

      // Ground shadow oval
      final scale = 0.35 + 0.65 * ((bounce + 1) / 2);
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(x, shadowY),
            width: r * 2.8 * scale,
            height: r * 0.6 * scale),
        Paint()..color = color.withOpacity(0.22 * scale),
      );

      // Glow halo
      canvas.drawCircle(Offset(x, y), r * 1.8, Paint()
        ..color = color.withOpacity(0.30)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r));

      // Main dot
      canvas.drawCircle(Offset(x, y), r, Paint()..color = color);

      // Specular highlight
      canvas.drawCircle(
          Offset(x - r * 0.30, y - r * 0.30),
          r * 0.32,
          Paint()..color = Colors.white.withOpacity(0.72));
    }
  }

  @override
  bool shouldRepaint(covariant _DotsPainter old) => old.t != t;
}

// ────────────────────────────────────────────────────────────────────────────
// STYLE 8 · WAVE  — 3 layered sine waves scrolling left-to-right
// ────────────────────────────────────────────────────────────────────────────
class _WavePainter extends CustomPainter {
  final double t;
  final Color color;
  const _WavePainter({required this.t, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final cy = size.height / 2;
    final amp = size.height * 0.28;
    final baseStroke = size.width * 0.052;

    for (int w = 0; w < 3; w++) {
      final phaseShift = w * math.pi * 2 / 3;
      final op = [1.0, 0.45, 0.20][w];
      final sw = baseStroke * [1.0, 0.7, 0.45][w];
      final path = Path();
      const steps = 80;
      for (int i = 0; i <= steps; i++) {
        final xn = i / steps;
        final x = xn * size.width;
        final y = cy + amp * math.sin(xn * 4 * math.pi - t * 2 * math.pi + phaseShift);
        if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
      }
      canvas.drawPath(path, Paint()
        ..color = color.withOpacity(op * 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw * 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, sw * 1.5));
      canvas.drawPath(path, Paint()
        ..color = color.withOpacity(op)
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round);
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) => old.t != t;
}

// ────────────────────────────────────────────────────────────────────────────
// STYLE 9 · CLOCK  — rotating hour + minute hands, tick marks, glowing tip
// ────────────────────────────────────────────────────────────────────────────
class _ClockPainter extends CustomPainter {
  final double t;
  final Color color;
  const _ClockPainter({required this.t, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.42;
    final c = Offset(cx, cy);

    canvas.drawCircle(c, r, Paint()
      ..color = color.withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0);

    for (int i = 0; i < 12; i++) {
      final a = i * math.pi / 6 - math.pi / 2;
      final isMajor = i % 3 == 0;
      canvas.drawLine(
        Offset(cx + (isMajor ? r * 0.80 : r * 0.88) * math.cos(a),
               cy + (isMajor ? r * 0.80 : r * 0.88) * math.sin(a)),
        Offset(cx + r * math.cos(a), cy + r * math.sin(a)),
        Paint()
          ..color = color.withOpacity(isMajor ? 0.65 : 0.25)
          ..strokeWidth = isMajor ? size.width * 0.038 : size.width * 0.022
          ..strokeCap = StrokeCap.round,
      );
    }

    final hourAngle = t * 2 * math.pi / 12 - math.pi / 2;
    canvas.drawLine(c,
      Offset(cx + r * 0.50 * math.cos(hourAngle),
             cy + r * 0.50 * math.sin(hourAngle)),
      Paint()
        ..color = color.withOpacity(0.55)
        ..strokeWidth = size.width * 0.055
        ..strokeCap = StrokeCap.round);

    final minAngle = t * 2 * math.pi - math.pi / 2;
    final minTip = Offset(cx + r * 0.72 * math.cos(minAngle),
                          cy + r * 0.72 * math.sin(minAngle));
    canvas.drawCircle(minTip, size.width * 0.065, Paint()
      ..color = color.withOpacity(0.45)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
    canvas.drawLine(c, minTip, Paint()
      ..color = color.withOpacity(0.92)
      ..strokeWidth = size.width * 0.042
      ..strokeCap = StrokeCap.round);

    canvas.drawCircle(c, size.width * 0.060, Paint()..color = color);
    canvas.drawCircle(c, size.width * 0.032,
        Paint()..color = Colors.white.withOpacity(0.88));
  }

  @override
  bool shouldRepaint(covariant _ClockPainter old) => old.t != t;
}

// ────────────────────────────────────────────────────────────────────────────
// STYLE 10 · SPIRAL  — 18 glowing dots on a rotating Archimedean spiral
// ────────────────────────────────────────────────────────────────────────────
class _SpiralPainter extends CustomPainter {
  final double t;
  final Color color;
  const _SpiralPainter({required this.t, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final maxR = size.width * 0.44;
    const numDots = 18;
    const turns = 2.2;

    for (int i = 0; i < numDots; i++) {
      final frac = i / (numDots - 1);
      final r = frac * maxR;
      final theta = frac * turns * 2 * math.pi + t * 2 * math.pi;
      final x = cx + r * math.cos(theta);
      final y = cy + r * math.sin(theta);
      final dotR = size.width * 0.038 * (0.25 + 0.75 * frac);
      final op = 0.20 + 0.80 * frac;
      canvas.drawCircle(Offset(x, y), dotR * 2.0, Paint()
        ..color = color.withOpacity(op * 0.28)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, dotR));
      canvas.drawCircle(Offset(x, y), dotR, Paint()..color = color.withOpacity(op));
    }
  }

  @override
  bool shouldRepaint(covariant _SpiralPainter old) => old.t != t;
}

// ────────────────────────────────────────────────────────────────────────────
// STYLE 11 · ATOM  — 3 elliptical electron orbits around a pulsing nucleus
// ────────────────────────────────────────────────────────────────────────────
class _AtomPainter extends CustomPainter {
  final double t;
  final Color color;
  const _AtomPainter({required this.t, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final orbitR = size.width * 0.38;
    final orbitMinor = size.height * 0.16;

    for (int i = 0; i < 3; i++) {
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(i * math.pi / 3);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero,
            width: orbitR * 2, height: orbitMinor * 2),
        Paint()
          ..color = color.withOpacity(0.18)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
      final ea = t * 2 * math.pi * (1.0 + i * 0.35);
      final ex = orbitR * math.cos(ea);
      final ey = orbitMinor * math.sin(ea);
      canvas.drawCircle(Offset(ex, ey), size.width * 0.065, Paint()
        ..color = color.withOpacity(0.42)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
      canvas.drawCircle(Offset(ex, ey), size.width * 0.048, Paint()..color = color);
      canvas.restore();
    }

    final nr = size.width * 0.095 * (0.8 + 0.2 * math.sin(t * 6 * math.pi));
    canvas.drawCircle(Offset(cx, cy), nr, Paint()
      ..color = color.withOpacity(0.50)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
    canvas.drawCircle(Offset(cx, cy), nr * 0.55, Paint()..color = color);
    canvas.drawCircle(Offset(cx, cy), nr * 0.28,
        Paint()..color = Colors.white.withOpacity(0.82));
  }

  @override
  bool shouldRepaint(covariant _AtomPainter old) => old.t != t;
}

// ────────────────────────────────────────────────────────────────────────────
// STYLE 12 · RIPPLE  — 4 concentric expanding diamonds (angular sonar)
// ────────────────────────────────────────────────────────────────────────────
class _RipplePainter extends CustomPainter {
  final double t;
  final Color color;
  const _RipplePainter({required this.t, required this.color});

  Path _diamond(double cx, double cy, double r) => Path()
    ..moveTo(cx, cy - r)
    ..lineTo(cx + r, cy)
    ..lineTo(cx, cy + r)
    ..lineTo(cx - r, cy)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final maxR = size.width * 0.44;

    for (int i = 0; i < 4; i++) {
      final rt = (t + i / 4.0) % 1.0;
      final r = rt * maxR;
      final op = (1 - rt) * 0.88;
      final sw = (1.0 - rt * 0.55) * 1.8;
      final d = _diamond(cx, cy, r);
      canvas.drawPath(d, Paint()
        ..color = color.withOpacity(op * 0.38)
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw * 2.8
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, sw * 2));
      canvas.drawPath(d, Paint()
        ..color = color.withOpacity(op)
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw
        ..strokeJoin = StrokeJoin.round);
    }

    final pr = size.width * 0.07 * (0.7 + 0.3 * math.sin(t * 6 * math.pi));
    canvas.drawPath(_diamond(cx, cy, pr), Paint()..color = color.withOpacity(0.90));
    canvas.drawCircle(Offset(cx, cy), pr * 0.45,
        Paint()..color = Colors.white.withOpacity(0.82));
  }

  @override
  bool shouldRepaint(covariant _RipplePainter old) => old.t != t;
}

// ────────────────────────────────────────────────────────────────────────────
// STYLE 13 · BOUNCE  — single dot with squish physics (FAST 400ms)
// ────────────────────────────────────────────────────────────────────────────
class _BouncePainter extends CustomPainter {
  final double t;
  final Color color;
  const _BouncePainter({required this.t, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final cx = size.width / 2;
    final groundY = size.height * 0.84;
    final topY = size.height * 0.14;
    final r = size.width * 0.17;

    // Parabolic bounce: abs(sin) gives natural arc
    final bounce = math.sin(t * math.pi).clamp(0.0, 1.0);
    final y = groundY - (groundY - topY) * bounce;

    // Squish: flatter + wider at ground impact
    final sx = 1.0 + 0.45 * (1 - bounce); // wider at bottom
    final sy = 1.0 - 0.38 * (1 - bounce); // shorter at bottom

    // Shadow on ground
    final shadowSc = 0.18 + 0.82 * (1 - bounce);
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx, groundY + r * 0.2),
          width: r * 3.2 * shadowSc,
          height: r * 0.45 * shadowSc),
      Paint()..color = color.withOpacity(0.28 * shadowSc));

    // Motion-blur trail
    for (int i = 6; i >= 1; i--) {
      final prevBounce =
          math.sin((t - i * 0.045) * math.pi).clamp(0.0, 1.0);
      final prevY = groundY - (groundY - topY) * prevBounce;
      canvas.drawCircle(Offset(cx, prevY), r * (1 - i * 0.14),
          Paint()..color = color.withOpacity((1 - i * 0.14) * 0.22));
    }

    // Glow
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx, y),
          width: r * 2 * sx * 1.9,
          height: r * 2 * sy * 1.9),
      Paint()
        ..color = color.withOpacity(0.30)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r));

    // Body
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx, y), width: r * 2 * sx, height: r * 2 * sy),
      Paint()..color = color);

    // Specular
    canvas.drawCircle(Offset(cx - r * sx * 0.28, y - r * sy * 0.28),
        r * 0.30, Paint()..color = Colors.white.withOpacity(0.75));
  }

  @override
  bool shouldRepaint(covariant _BouncePainter old) => old.t != t;
}

// ────────────────────────────────────────────────────────────────────────────
// STYLE 14 · SPARK  — 10 radiating spark lines exploding from centre (FAST 280ms)
// ────────────────────────────────────────────────────────────────────────────
class _SparkPainter extends CustomPainter {
  final double t;
  final Color color;
  const _SparkPainter({required this.t, required this.color});

  // Fixed spoke angles so each cycle is identical
  static const _angles = [
    0.0, 0.628, 1.257, 1.885, 2.513,
    3.14, 3.770, 4.398, 5.027, 5.655
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final maxLen = size.width * 0.44;

    for (int i = 0; i < _angles.length; i++) {
      // Each spark staggered slightly so they don't all fire together
      final st = (t + i * 0.08) % 1.0;
      final len = st * maxLen;
      final op = (1 - st) * 0.92;
      final sw = (1 - st) * size.width * 0.045 + 0.8;
      final angle = _angles[i];

      // Spark is a line from ~15% to 100% of its length (head-gap)
      canvas.drawLine(
        Offset(cx + len * 0.18 * math.cos(angle),
               cy + len * 0.18 * math.sin(angle)),
        Offset(cx + len * math.cos(angle), cy + len * math.sin(angle)),
        Paint()
          ..color = color.withOpacity(op)
          ..strokeWidth = sw
          ..strokeCap = StrokeCap.round
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, sw * 0.8),
      );
    }

    // Centre flash
    final fr = size.width * 0.09 * (1 - t);
    canvas.drawCircle(Offset(cx, cy), fr + 1, Paint()
      ..color = color.withOpacity((1 - t) * 0.85)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, fr));
    canvas.drawCircle(Offset(cx, cy), fr * 0.45,
        Paint()..color = Colors.white.withOpacity((1 - t) * 0.95));
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) => old.t != t;
}

// ────────────────────────────────────────────────────────────────────────────
// STYLE 15 · GLITCH  — digital slice displacement (FAST 260ms)
// ────────────────────────────────────────────────────────────────────────────
class _GlitchPainter extends CustomPainter {
  final double t;
  final Color color;
  const _GlitchPainter({required this.t, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final cx = size.width / 2;

    // Quantise to sharp frames (creates the glitch "step" feel)
    final frame = (t * 10).floor();
    const numSlices = 9;
    final sliceH = size.height / numSlices;
    final baseW = size.width * 0.52;

    for (int i = 0; i < numSlices; i++) {
      // Deterministic pseudo-random offset per frame+slice
      final hash = ((frame * 17 + i * 31 + 3) % 11) - 5; // -5..5
      final xOff = hash * size.width * 0.055;

      // Width flicker
      final wHash = ((frame * 7 + i * 13) % 5);
      final w = baseW * (0.55 + wHash * 0.10);

      // Occasional "bright" slice
      final isHot = ((frame * 3 + i * 7) % 8) == 0;
      final op = isHot ? 1.0 : (0.45 + ((frame + i) % 3) * 0.15);

      final x = (cx - w / 2 + xOff).clamp(0.0, size.width - w);
      final y = i * sliceH;

      // Glow on hot slices
      if (isHot) {
        canvas.drawRect(
          Rect.fromLTWH(x, y, w, sliceH * 0.85),
          Paint()
            ..color = color.withOpacity(0.50)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
      }

      canvas.drawRect(
        Rect.fromLTWH(x, y + 0.5, w, sliceH * 0.82),
        Paint()..color = (isHot ? Colors.white : color).withOpacity(op));
    }

    // Scanline sweep
    final scanY = (t * 10).floor() / 10.0 * size.height;
    canvas.drawRect(
      Rect.fromLTWH(0, scanY, size.width, 1.5),
      Paint()..color = Colors.white.withOpacity(0.55));
  }

  @override
  bool shouldRepaint(covariant _GlitchPainter old) => old.t != t;
}

// ────────────────────────────────────────────────────────────────────────────
// STYLE 16 · LOTUS  — 8 petals blooming and rotating (SLOW 4500ms)
// ────────────────────────────────────────────────────────────────────────────
class _LotusPainter extends CustomPainter {
  final double t;
  final Color color;
  const _LotusPainter({required this.t, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final cx = size.width / 2;
    final cy = size.height / 2;
    const numPetals = 8;
    final petalLen = size.width * 0.33;
    final petalW = size.width * 0.13;

    // Bloom opens in first 40% of cycle, then stays open and rotates
    final bloom = _ease((t * 2.5).clamp(0.0, 1.0));
    final rotation = t * 2 * math.pi * 0.5; // half rotation per cycle

    for (int i = 0; i < numPetals; i++) {
      final angle = i * 2 * math.pi / numPetals + rotation;

      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(angle);

      // Petal: ellipse offset from centre, scaled by bloom
      final dist = petalLen * 0.48 * bloom;
      final glow = Rect.fromCenter(
          center: Offset(0, -dist), width: petalW * 2 * bloom, height: petalLen * bloom);
      canvas.drawOval(glow, Paint()
        ..color = color.withOpacity(0.28 * bloom)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3));
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(0, -dist),
            width: petalW * bloom,
            height: petalLen * 0.9 * bloom),
        Paint()..color = color.withOpacity(0.70 * bloom));

      canvas.restore();
    }

    // Centre stamen
    final cr = size.width * 0.065 * bloom;
    canvas.drawCircle(Offset(cx, cy), cr, Paint()
      ..color = color.withOpacity(0.9)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3));
    canvas.drawCircle(Offset(cx, cy), cr * 0.55,
        Paint()..color = Colors.white.withOpacity(0.85));
  }

  @override
  bool shouldRepaint(covariant _LotusPainter old) => old.t != t;
}

// ────────────────────────────────────────────────────────────────────────────
// STYLE 17 · RING  — arc fills then drains clockwise (medium 1500ms)
// ────────────────────────────────────────────────────────────────────────────
class _RingPainter extends CustomPainter {
  final double t;
  final Color color;
  const _RingPainter({required this.t, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width * 0.38;
    final sw = size.width * 0.095;
    final trackRect = Rect.fromCircle(center: c, radius: r);

    // Background track
    canvas.drawCircle(c, r, Paint()
      ..color = color.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw);

    // Phase 0→0.5: fill (sweep grows 0→2π), 0.5→1.0: drain (start advances)
    final double startAngle;
    final double sweepAngle;
    const base = -math.pi / 2;
    if (t < 0.5) {
      final frac = _ease(t * 2);
      startAngle = base;
      sweepAngle = frac * 2 * math.pi;
    } else {
      final frac = _ease((t - 0.5) * 2);
      startAngle = base + frac * 2 * math.pi;
      sweepAngle = (1 - frac) * 2 * math.pi;
    }

    if (sweepAngle < 0.01) return;

    // Glow
    canvas.drawArc(trackRect, startAngle, sweepAngle, false, Paint()
      ..color = color.withOpacity(0.40)
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw * 2.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, sw * 1.2));

    // Arc with gradient
    canvas.drawArc(trackRect, startAngle, sweepAngle, false, Paint()
      ..shader = SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + sweepAngle,
        colors: [color.withOpacity(0.25), color],
      ).createShader(trackRect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw
      ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.t != t;
}

// ────────────────────────────────────────────────────────────────────────────
// STYLE 18 · CUBE  — 3 concentric squares counter-rotating (medium 2200ms)
// ────────────────────────────────────────────────────────────────────────────
class _CubePainter extends CustomPainter {
  final double t;
  final Color color;
  const _CubePainter({required this.t, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final cx = size.width / 2;
    final cy = size.height / 2;

    // 3 concentric squares, each at a different size, rotating at different speeds
    final configs = [
      (r: size.width * 0.40, speed: 1.0,  dir:  1, sw: size.width * 0.038, op: 0.95),
      (r: size.width * 0.27, speed: 1.6,  dir: -1, sw: size.width * 0.032, op: 0.70),
      (r: size.width * 0.15, speed: 2.5,  dir:  1, sw: size.width * 0.025, op: 0.45),
    ];

    for (final cfg in configs) {
      final angle = t * 2 * math.pi * cfg.speed * cfg.dir + math.pi / 4;
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(angle);

      final rect = Rect.fromCenter(
          center: Offset.zero, width: cfg.r * 2, height: cfg.r * 2);

      // Glow
      canvas.drawRect(rect, Paint()
        ..color = color.withOpacity(cfg.op * 0.30)
        ..style = PaintingStyle.stroke
        ..strokeWidth = cfg.sw * 2.5
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, cfg.sw * 2));

      // Edge
      canvas.drawRect(rect, Paint()
        ..color = color.withOpacity(cfg.op)
        ..style = PaintingStyle.stroke
        ..strokeWidth = cfg.sw
        ..strokeJoin = StrokeJoin.miter);

      canvas.restore();
    }

    // Centre dot
    final pr = size.width * 0.055 * (0.75 + 0.25 * math.sin(t * 6 * math.pi));
    canvas.drawCircle(Offset(cx, cy), pr, Paint()
      ..color = color.withOpacity(0.85)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3));
    canvas.drawCircle(Offset(cx, cy), pr * 0.50,
        Paint()..color = Colors.white.withOpacity(0.85));
  }

  @override
  bool shouldRepaint(covariant _CubePainter old) => old.t != t;
}
