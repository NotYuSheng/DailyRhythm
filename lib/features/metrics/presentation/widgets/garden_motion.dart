import 'dart:math' as math;

import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

import '../../../garden/domain/garden_scene.dart';

/// The garden scene, gently alive: each ridge of plants sways in a breeze
/// that rolls from the front ridge to the back, and the season's weather
/// moves (clouds drift, petals and leaves fall, snow drifts, birds glide,
/// fireflies blink). Still when the system asks for reduced motion.
class GardenMotion extends StatefulWidget {
  const GardenMotion({super.key, required this.layers, required this.look, required this.seed});

  /// The scene without its weather (see [GardenScene.layers]).
  final List<SceneLayer> layers;
  final SceneLook look;
  final int seed;

  @override
  State<GardenMotion> createState() => _GardenMotionState();
}

class _GardenMotionState extends State<GardenMotion> with SingleTickerProviderStateMixin {
  /// One long loop; everything moves on periods that divide it, so the loop
  /// has no visible seam.
  static const loop = Duration(seconds: 60);
  late final AnimationController _clock = AnimationController(vsync: this, duration: loop)..repeat();

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double seconds() => _clock.value * loop.inSeconds;
    return Stack(
      fit: StackFit.expand,
      children: [
        for (final (i, layer) in widget.layers.indexed)
          if (layer.swayBaseY case final base?)
            AnimatedBuilder(
              animation: _clock,
              builder: (context, child) {
                // A 5 s breeze (12 a loop), a little later on each ridge
                // further back; plants lean from where they stand.
                final phase = seconds() / 5 * 2 * math.pi - i * 0.5;
                final lean = (math.sin(phase) * 0.8 + math.sin(phase * 2 + 1) * 0.2) * 0.022;
                return Transform(
                  alignment: Alignment(0, base / GardenScene.height * 2 - 1),
                  transform: Matrix4.skewX(lean),
                  child: child,
                );
              },
              child: RepaintBoundary(child: SvgPicture.string(layer.svg, fit: BoxFit.cover)),
            )
          else
            RepaintBoundary(child: SvgPicture.string(layer.svg, fit: BoxFit.cover)),
        IgnorePointer(
          child: CustomPaint(painter: _Weather(widget.look, widget.seed, _clock, seconds)),
        ),
      ],
    );
  }
}

/// The season's moving weather, in the scene's coordinates.
class _Weather extends CustomPainter {
  _Weather(this.look, this.seed, Listenable clock, this.seconds) : super(repaint: clock);

  final SceneLook look;
  final int seed;
  final double Function() seconds;

  static const w = GardenScene.width, h = GardenScene.height;

  @override
  void paint(Canvas canvas, Size size) {
    // Cover, like the SVG layers: scale to fill, centred.
    final scale = math.max(size.width / w, size.height / h);
    canvas
      ..save()
      ..clipRect(Offset.zero & size)
      ..translate((size.width - w * scale) / 2, (size.height - h * scale) / 2)
      ..scale(scale);
    final t = seconds();
    final rng = math.Random(seed * 31 + look.index);
    switch (look) {
      case SceneLook.spring:
        _falling(canvas, rng, t, count: 9, colours: const [Color(0xFFF6C9D8), Color(0xFFFBE3EC), Color(0xFFF2B3C8)], petal: true);
      case SceneLook.summer:
        _clouds(canvas, t);
        _motes(canvas, rng, t);
      case SceneLook.autumn:
        _falling(canvas, rng, t, count: 10, colours: const [Color(0xFFE39B5A), Color(0xFFD7713F), Color(0xFFF0B657)], petal: false);
      case SceneLook.winter:
        _snow(canvas, rng, t);
      case SceneLook.wholeYear:
        _birds(canvas, t);
      case SceneLook.night:
        _fireflies(canvas, rng, t);
    }
    canvas.restore();
  }

  /// An angle turning [turns] times a loop at [t] seconds, so motion
  /// built from it meets itself where the loop starts again.
  static double _a(double t, num turns) => t / 60 * 2 * math.pi * turns;

  /// Wraps [v] into 0..[span].
  static double _wrap(double v, double span) => ((v % span) + span) % span;

  /// Petals or leaves drifting down and across, turning as they go. Each
  /// crosses the scene a whole number of times a loop.
  void _falling(Canvas canvas, math.Random rng, double t, {required int count, required List<Color> colours, required bool petal}) {
    for (var i = 0; i < count; i++) {
      final laps = 2 + rng.nextInt(2); // falls 2–3 times a minute
      final x0 = rng.nextDouble() * w, y0 = rng.nextDouble() * (h + 20);
      final colour = colours[rng.nextInt(colours.length)];
      final spin = rng.nextDouble() * math.pi * 2;
      final progress = t / 60 * laps;
      final y = _wrap(y0 + progress * (h + 20), h + 20) - 10;
      final x = _wrap(x0 + t / 60 * (w + 20) + math.sin(_a(t, 9) + i) * 8, w + 20) - 10;
      canvas
        ..save()
        ..translate(x, y)
        ..rotate(spin + _a(t, 5 + i % 3) * (i.isEven ? 1 : -1));
      final paint = Paint()..color = colour.withValues(alpha: 0.9);
      if (petal) {
        canvas.drawOval(const Rect.fromLTWH(-3, -1.8, 6, 3.6), paint);
      } else {
        canvas.drawPath(
          Path()
            ..moveTo(0, 0)
            ..cubicTo(3, -4, 8, -4, 10, 0)
            ..cubicTo(8, 4, 3, 4, 0, 0)
            ..close(),
          paint,
        );
      }
      canvas.restore();
    }
  }

  void _snow(Canvas canvas, math.Random rng, double t) {
    final paint = Paint()..color = const Color(0xE6FFFFFF);
    for (var i = 0; i < 26; i++) {
      final laps = 2 + rng.nextInt(3);
      final x0 = rng.nextDouble() * w, y0 = rng.nextDouble() * h;
      final r = 1 + rng.nextDouble() * 1.2;
      final y = _wrap(y0 + t / 60 * laps * (h + 10), h + 10) - 5;
      final x = x0 + math.sin(_a(t, 7) + i * 1.3) * 6;
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  void _clouds(Canvas canvas, double t) {
    final paint = Paint()..color = const Color(0xF2FFFFFF);
    // Once across a loop, slowly.
    final drift = t / 60 * (w + 120);
    for (final (cx, cy, rx, ry) in const [(70.0, 40.0, 28.0, 10.0), (92.0, 34.0, 18.0, 9.0), (190.0, 58.0, 22.0, 7.0)]) {
      final x = _wrap(cx + drift, w + 120) - 60;
      canvas.drawOval(Rect.fromCenter(center: Offset(x, cy), width: rx * 2, height: ry * 2), paint);
    }
  }

  /// Specks of pollen floating in the summer air.
  void _motes(Canvas canvas, math.Random rng, double t) {
    for (var i = 0; i < 8; i++) {
      final x0 = 30 + rng.nextDouble() * 270, y0 = 90 + rng.nextDouble() * 100;
      final x = x0 + math.sin(_a(t, 5) + i * 2) * 10;
      final y = y0 + math.cos(_a(t, 4) + i) * 6;
      final glow = 0.4 + 0.4 * math.sin(_a(t, 11) + i).abs();
      canvas.drawCircle(Offset(x, y), 1.4, Paint()..color = const Color(0xFFFFF6C8).withValues(alpha: glow));
    }
  }

  /// The golden-hour birds gliding across, wings beating now and then.
  void _birds(Canvas canvas, double t) {
    final paint = Paint()
      ..color = const Color(0xFF7A5A6A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    for (final (i, (x0, y0, size)) in const [(60.0, 46.0, 5.0), (92.0, 58.0, 4.0), (120.0, 40.0, 3.0)].indexed) {
      final x = _wrap(x0 + t / 60 * 2 * (w + 40), w + 40) - 20;
      final y = y0 + math.sin(_a(t, 8) + i) * 3;
      final flap = math.sin(_a(t, 57) + i * 2) * 0.5 + 0.5; // 0 glide, 1 wings up
      final lift = size * (0.6 + flap * 0.6);
      canvas.drawPath(
        Path()
          ..moveTo(x - size * 2, y)
          ..quadraticBezierTo(x - size, y - lift, x, y)
          ..quadraticBezierTo(x + size, y - lift, x + size * 2, y),
        paint,
      );
    }
  }

  void _fireflies(Canvas canvas, math.Random rng, double t) {
    for (var i = 0; i < 10; i++) {
      final x0 = 30 + rng.nextDouble() * 270, y0 = 90 + rng.nextDouble() * 110;
      final turns = 2 + rng.nextInt(3);
      final x = x0 + math.sin(_a(t, turns) + i) * 14;
      final y = y0 + math.sin(_a(t, turns + 1) + i * 2) * 8;
      // Each blinks on its own rhythm.
      final glow = math.pow(math.sin(_a(t, 8 + i % 4 * 2) + i).abs(), 3).toDouble();
      canvas
        ..drawCircle(Offset(x, y), 5, Paint()..color = const Color(0xFFFFF3A0).withValues(alpha: 0.18 * glow))
        ..drawCircle(Offset(x, y), 2.2, Paint()..color = const Color(0xFFFFF3A0).withValues(alpha: 0.3 + 0.7 * glow));
    }
  }

  @override
  bool shouldRepaint(_Weather old) => old.look != look || old.seed != seed;
}
