import 'dart:math';

import 'package:flutter/material.dart';

import 'journey_ui.dart';

Paint _fill(Color color) => Paint()..color = color;

Paint _line(Color color, [double width = 2.5]) => Paint()
  ..color = color
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

Path _shape(List<double> points, {bool close = true}) {
  final path = Path()..moveTo(points[0], points[1]);
  for (var i = 2; i < points.length; i += 2) {
    path.lineTo(points[i], points[i + 1]);
  }
  if (close) path.close();
  return path;
}

void _solid(
  Canvas canvas,
  Path path,
  Color color, {
  Color edge = J.ink,
  double width = 2.5,
}) {
  canvas.drawPath(path, _fill(color));
  canvas.drawPath(path, _line(edge, width));
}

void _dashedCircle(
  Canvas canvas,
  Offset centre,
  double radius,
  Paint paint, {
  int dashes = 14,
}) {
  final sweep = 2 * pi / dashes;
  for (var i = 0; i < dashes; i++) {
    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: radius),
      i * sweep,
      sweep * 0.55,
      false,
      paint,
    );
  }
}

void _dots(
  Canvas canvas,
  Path path,
  Color color, {
  double gap = 10,
  double width = 2.5,
}) {
  final paint = _fill(color);
  for (final metric in path.computeMetrics()) {
    for (var at = 0.0; at < metric.length; at += gap) {
      final spot = metric.getTangentForOffset(at);
      if (spot != null) canvas.drawCircle(spot.position, width / 2, paint);
    }
  }
}

/// An arch standing on the ground: a cave mouth, a doorway of light.
Path _arch(double left, double right, double ground, double shoulder) {
  final radius = (right - left) / 2;
  return Path()
    ..moveTo(left, ground)
    ..lineTo(left, shoulder)
    ..arcToPoint(Offset(right, shoulder), radius: Radius.circular(radius))
    ..lineTo(right, ground)
    ..close();
}

/// Where a stop stands on the map.
enum LanternState { lit, open, locked }

/// A stop's lantern: lit, waiting to be played, or still closed.
class Lantern extends StatelessWidget {
  const Lantern({
    super.key,
    required this.state,
    this.number = '',
    this.size = 60,
    this.onDark = true,
  });

  final LanternState state;

  /// The stop's number, in the digits the player reads. Drawn while locked.
  final String number;
  final double size;
  final bool onDark;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _LanternPainter(state, number, onDark),
  );
}

class _LanternPainter extends CustomPainter {
  const _LanternPainter(this.state, this.number, this.onDark);

  final LanternState state;
  final String number;
  final bool onDark;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 60);
    const centre = Offset(30, 30);
    switch (state) {
      case LanternState.lit:
        canvas.drawCircle(centre, 26.5, _fill(J.sun));
        canvas.drawCircle(centre, 26.5, _line(J.ink, 3));
        final flame = Path()
          ..moveTo(30, 16)
          ..cubicTo(37, 24, 38, 29, 38, 33)
          ..arcToPoint(const Offset(22, 33), radius: const Radius.circular(8))
          ..cubicTo(22, 29, 23, 24, 30, 16)
          ..close();
        _solid(canvas, flame, J.white, width: 2.6);
      case LanternState.open:
        canvas.drawCircle(centre, 27, _fill(J.white));
        canvas.drawCircle(centre, 27, _line(J.sun, 5));
        canvas.drawPath(_shape([25, 20, 41, 30, 25, 40]), _fill(J.ink));
      case LanternState.locked:
        canvas.drawCircle(centre, 26, _fill(onDark ? J.deep : J.white));
        _dashedCircle(canvas, centre, 26, _line(onDark ? J.white : J.grey));
        final text = TextPainter(
          text: TextSpan(
            text: number,
            style: J.text(22, weight: 800, color: onDark ? J.white : J.grey),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        text.paint(canvas, centre - Offset(text.width / 2, text.height / 2));
    }
  }

  @override
  bool shouldRepaint(_LanternPainter old) =>
      old.state != state || old.number != number || old.onDark != onDark;
}

/// A keepsake as a small round badge: found, or still an empty outline.
class KeepsakeBadge extends StatelessWidget {
  const KeepsakeBadge({
    super.key,
    required this.id,
    required this.found,
    required this.label,
    this.size = 40,
    this.onDark = false,
  });

  final String id;
  final bool found;
  final String label;
  final double size;
  final bool onDark;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: label,
    child: CustomPaint(
      size: Size.square(size),
      painter: _KeepsakePainter(id, found: found, onDark: onDark, rays: false),
    ),
  );
}

/// A keepsake drawn large, with rays, for the moment it is found.
class KeepsakeArt extends StatelessWidget {
  const KeepsakeArt({
    super.key,
    required this.id,
    required this.label,
    this.width = 240,
  });

  final String id;
  final String label;
  final double width;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: label,
    child: CustomPaint(
      size: Size(width, width * 190 / 240),
      painter: _KeepsakePainter(id, found: true, onDark: true, rays: true),
    ),
  );
}

class _KeepsakePainter extends CustomPainter {
  const _KeepsakePainter(
    this.id, {
    required this.found,
    required this.onDark,
    required this.rays,
  });

  final String id;
  final bool found;
  final bool onDark;
  final bool rays;

  @override
  void paint(Canvas canvas, Size size) {
    if (rays) {
      canvas.scale(size.width / 240);
      for (final ray in const [
        [120.0, 4.0, 132.0, 44.0, 108.0, 44.0],
        [196.0, 34.0, 172.0, 68.0, 156.0, 52.0],
        [230.0, 104.0, 190.0, 108.0, 190.0, 86.0],
        [44.0, 34.0, 84.0, 52.0, 68.0, 68.0],
        [10.0, 104.0, 50.0, 86.0, 50.0, 108.0],
      ]) {
        _solid(canvas, _shape(ray), J.sun);
      }
      canvas.translate(120 - 68, 112 - 68);
      canvas.scale(136 / 40);
    } else {
      canvas.scale(size.width / 40);
    }
    // Everything below is drawn in a box of 40.
    const centre = Offset(20, 20);
    final thin = rays ? 0.9 : 2.0;
    if (!found) {
      canvas.drawCircle(centre, 17, _fill(onDark ? Colors.transparent : J.bg));
      _dashedCircle(
        canvas,
        centre,
        17,
        _line(onDark ? J.white : J.ink, 2),
        dashes: 13,
      );
      if (!onDark) _icon(canvas, const Color(0xFF5B6F86), null, 2);
      return;
    }
    final ground = switch (id) {
      'coin' => J.silver,
      'vine' => J.tealPale,
      'ship' => J.lilacPale,
      _ => J.sunPale,
    };
    canvas.drawCircle(centre, 18, _fill(ground));
    canvas.drawCircle(centre, 18, _line(J.ink, rays ? 0.9 : 2.2));
    if (id == 'coin') {
      _dashedCircle(
        canvas,
        centre,
        14,
        _line(const Color(0xFF6F8498), rays ? 0.7 : 1),
        dashes: 22,
      );
    }
    _icon(canvas, J.ink, ground, thin);
    if (rays) {
      canvas.drawArc(
        Rect.fromCircle(center: centre, radius: 15),
        pi * 1.08,
        pi * 0.3,
        false,
        _line(J.white, 1.4),
      );
    }
  }

  /// The thing itself. With [ground] it is coloured in; without, an outline.
  void _icon(Canvas canvas, Color edge, Color? ground, double width) {
    final coloured = ground != null;
    void draw(Path path, Color color) {
      if (coloured) canvas.drawPath(path, _fill(color));
      canvas.drawPath(path, _line(edge, width));
    }

    switch (id) {
      case 'coin':
        if (coloured) {
          draw(
            _shape([
              20,
              10.5,
              22.7,
              17.3,
              29.5,
              20,
              22.7,
              22.7,
              20,
              29.5,
              17.3,
              22.7,
              10.5,
              20,
              17.3,
              17.3,
            ]),
            J.steel,
          );
        } else {
          canvas.drawCircle(const Offset(20, 20), 8, _line(edge, width));
        }
      case 'vine':
        canvas.drawPath(
          _shape([20, 9, 20, 14], close: false),
          _line(edge, width),
        );
        if (coloured) {
          draw(
            Path()
              ..moveTo(20, 11)
              ..quadraticBezierTo(27, 7, 30, 13)
              ..quadraticBezierTo(24, 16, 20, 11)
              ..close(),
            J.leaf,
          );
        }
        for (final grape in const [
          Offset(14.5, 18.5),
          Offset(20, 18.5),
          Offset(25.5, 18.5),
          Offset(17.2, 23.5),
          Offset(22.8, 23.5),
          Offset(20, 28.5),
        ]) {
          draw(
            Path()..addOval(Rect.fromCircle(center: grape, radius: 2.9)),
            J.lilac,
          );
        }
      case 'ship':
        draw(_shape([20, 9, 20, 23, 28, 23]), J.white);
        draw(_shape([20, 12, 20, 23, 13.5, 23]), J.sunPale);
        draw(_shape([10, 24, 30, 24, 26.5, 30, 13.5, 30]), J.sun);
        if (coloured) {
          canvas.drawPath(
            Path()
              ..moveTo(8, 33)
              ..quadraticBezierTo(11, 31, 14, 33)
              ..quadraticBezierTo(17, 35, 20, 33)
              ..quadraticBezierTo(23, 31, 26, 33)
              ..quadraticBezierTo(29, 35, 32, 33),
            _line(J.teal, width * 1.2),
          );
        }
      default:
        for (final block in const [
          Rect.fromLTWH(11.5, 14, 8, 6),
          Rect.fromLTWH(20.5, 14, 8, 6),
          Rect.fromLTWH(16, 21, 8, 6),
          Rect.fromLTWH(7, 21, 8, 6),
          Rect.fromLTWH(25, 21, 8, 6),
        ]) {
          if (!coloured && (block.left < 10 || block.left > 24)) continue;
          draw(Path()..addRect(block), J.steel);
        }
    }
  }

  @override
  bool shouldRepaint(_KeepsakePainter old) =>
      old.id != id || old.found != found || old.onDark != onDark;
}

/// The picture at the top of a stop: a scene for its part of the surah.
class JourneyScene extends StatelessWidget {
  const JourneyScene({
    super.key,
    required this.art,
    this.height = 232,
    this.framed = true,
  });

  /// book, cave, gardens, rain, sea, wall, or hero for the first screen.
  final String art;
  final double height;
  final bool framed;

  @override
  Widget build(BuildContext context) {
    final picture = CustomPaint(
      size: Size(double.infinity, height),
      painter: _ScenePainter(art),
    );
    if (!framed) return ExcludeSemantics(child: picture);
    return ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Container(
          height: height,
          clipBehavior: Clip.antiAlias,
          decoration: J.box(color: _ScenePainter.sky(art), radius: 22),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(19),
            child: picture,
          ),
        ),
      ),
    );
  }
}

class _ScenePainter extends CustomPainter {
  const _ScenePainter(this.art);

  final String art;

  static Color sky(String art) => switch (art) {
    'cave' || 'wall' => J.deep,
    'book' => J.navy,
    'gardens' => J.tealPale,
    'rain' => J.lilacPale,
    'sea' => J.sunCream,
    _ => J.bg,
  };

  @override
  void paint(Canvas canvas, Size size) {
    // Drawn on a sheet 350 wide; the height follows the widget.
    final scale = size.width / 350;
    canvas.scale(scale);
    final h = size.height / scale;
    canvas.drawRect(Rect.fromLTWH(0, 0, 350, h), _fill(sky(art)));
    // Scenes are composed for a height of 232 and stand on the bottom edge.
    canvas.translate(0, h - 232);
    switch (art) {
      case 'cave':
        _stars(canvas);
        _moon(canvas);
        _solid(
          canvas,
          _shape([-4, 232, 84, 96, 140, 168, 206, 70, 300, 232]),
          J.navy,
        );
        _solid(canvas, _shape([232, 232, 300, 150, 356, 232]), J.lilac);
        canvas.drawPath(_arch(150, 222, 232, 188), _fill(J.ink));
        canvas.drawPath(_arch(172, 200, 232, 200), _fill(J.sun));
        for (final ray in const [
          [186.0, 176.0, 186.0, 164.0],
          [160.0, 184.0, 151.0, 175.0],
          [212.0, 184.0, 221.0, 175.0],
        ]) {
          canvas.drawPath(_shape(ray, close: false), _line(J.sunPale));
        }
        _dots(
          canvas,
          Path()
            ..moveTo(20, 226)
            ..quadraticBezierTo(60, 206, 90, 220)
            ..quadraticBezierTo(120, 232, 146, 222),
          J.white,
        );
      case 'wall':
        _stars(canvas);
        _solid(canvas, _shape([-10, 232, 70, 60, 150, 232]), J.navy);
        _solid(canvas, _shape([200, 232, 284, 52, 364, 232]), J.navy);
        _solid(canvas, _shape([-10, 232, 30, 150, 78, 232]), J.lilac);
        _solid(canvas, _shape([278, 232, 322, 160, 360, 232]), J.lilac);
        // The barrier: rows of iron blocks between the mountainsides.
        for (var row = 0; row < 5; row++) {
          final top = 232 - (row + 1) * 26.0;
          final inset = 108 - row * 5.0;
          final width = (350 - 2 * inset) / 4;
          for (var block = 0; block < 4; block++) {
            _solid(
              canvas,
              Path()
                ..addRect(Rect.fromLTWH(inset + block * width, top, width, 26)),
              row == 4 ? J.sun : J.steel,
            );
          }
        }
        canvas.drawPath(
          Path()
            ..moveTo(132, 96)
            ..quadraticBezierTo(175, 78, 218, 96),
          _line(J.sunPale, 3),
        );
      case 'book':
        _stars(canvas);
        for (final ray in const [
          [175.0, 66.0, 175.0, 30.0],
          [120.0, 84.0, 96.0, 56.0],
          [230.0, 84.0, 254.0, 56.0],
          [84.0, 122.0, 52.0, 110.0],
          [266.0, 122.0, 298.0, 110.0],
        ]) {
          canvas.drawPath(_shape(ray, close: false), _line(J.sun, 4));
        }
        _solid(canvas, _shape([62, 204, 62, 118, 175, 136, 175, 222]), J.white);
        _solid(
          canvas,
          _shape([288, 204, 288, 118, 175, 136, 175, 222]),
          J.sunCream,
        );
        for (var row = 0; row < 4; row++) {
          final y = 140.0 + row * 17;
          canvas.drawPath(
            _shape([80, y, 160, y + 13], close: false),
            _line(J.grey, 2),
          );
          canvas.drawPath(
            _shape([190, y + 13, 270, y], close: false),
            _line(J.grey, 2),
          );
        }
        canvas.drawPath(
          _shape([20, 230, 330, 230], close: false),
          _line(J.ink),
        );
      case 'gardens':
        canvas.drawCircle(const Offset(292, 46), 22, _fill(J.sun));
        canvas.drawCircle(const Offset(292, 46), 22, _line(J.ink));
        _solid(
          canvas,
          Path()
            ..moveTo(-4, 232)
            ..lineTo(-4, 150)
            ..quadraticBezierTo(80, 104, 168, 150)
            ..lineTo(168, 232)
            ..close(),
          J.leaf,
        );
        _solid(
          canvas,
          Path()
            ..moveTo(354, 232)
            ..lineTo(354, 142)
            ..quadraticBezierTo(270, 104, 190, 150)
            ..lineTo(190, 232)
            ..close(),
          J.leaf,
        );
        _solid(
          canvas,
          Path()
            ..moveTo(160, 232)
            ..quadraticBezierTo(190, 190, 170, 150)
            ..lineTo(192, 150)
            ..quadraticBezierTo(214, 190, 198, 232)
            ..close(),
          J.lilac,
        );
        for (final row in const [
          [18.0, 176.0],
          [44.0, 204.0],
          [226.0, 176.0],
          [214.0, 204.0],
        ]) {
          for (var i = 0; i < 4; i++) {
            final x = row[0] + i * 30;
            canvas.drawPath(
              _shape([x, row[1] + 14, x, row[1] - 6], close: false),
              _line(J.ink, 2),
            );
            for (final grape in [
              Offset(x - 5, row[1]),
              Offset(x + 5, row[1]),
              Offset(x, row[1] + 7),
            ]) {
              canvas.drawCircle(grape, 4.2, _fill(J.navy));
            }
          }
        }
        _palm(canvas, 36, 150);
        _palm(canvas, 322, 142);
      case 'rain':
        _solid(
          canvas,
          Path()
            ..moveTo(60, 86)
            ..arcToPoint(
              const Offset(96, 52),
              radius: const Radius.circular(24),
            )
            ..arcToPoint(
              const Offset(156, 44),
              radius: const Radius.circular(34),
            )
            ..arcToPoint(
              const Offset(206, 70),
              radius: const Radius.circular(28),
            )
            ..arcToPoint(
              const Offset(206, 110),
              radius: const Radius.circular(20),
            )
            ..lineTo(70, 110)
            ..arcToPoint(
              const Offset(60, 86),
              radius: const Radius.circular(14),
            )
            ..close(),
          J.white,
        );
        for (var i = 0; i < 6; i++) {
          final x = 78.0 + i * 24;
          canvas.drawPath(
            _shape([x, 124, x - 8, 144], close: false),
            _line(J.teal, 3.5),
          );
        }
        _solid(
          canvas,
          Path()
            ..moveTo(-4, 232)
            ..lineTo(-4, 196)
            ..quadraticBezierTo(175, 172, 354, 196)
            ..lineTo(354, 232)
            ..close(),
          J.leaf,
        );
        for (var i = 0; i < 5; i++) {
          final x = 34.0 + i * 30;
          canvas.drawPath(
            Path()
              ..moveTo(x, 196)
              ..quadraticBezierTo(x - 2, 176, x + 6, 160),
            _line(J.right, 3),
          );
          canvas.drawPath(
            Path()
              ..moveTo(x + 1, 182)
              ..quadraticBezierTo(x + 12, 176, x + 15, 166),
            _line(J.right, 3),
          );
        }
        for (var i = 0; i < 4; i++) {
          final x = 222.0 + i * 30;
          canvas.drawPath(
            Path()
              ..moveTo(x, 198)
              ..quadraticBezierTo(x + 6, 180, x + 26, 174),
            _line(J.sun, 3),
          );
        }
        for (final gust in const [
          [250.0, 130.0],
          [276.0, 150.0],
          [236.0, 160.0],
        ]) {
          canvas.drawPath(
            _shape([gust[0], gust[1], gust[0] + 44, gust[1]], close: false),
            _line(J.grey, 2),
          );
        }
      case 'sea':
        canvas.drawCircle(const Offset(280, 118), 34, _fill(J.sun));
        canvas.drawCircle(const Offset(280, 118), 34, _line(J.ink));
        canvas.drawRect(const Rect.fromLTWH(0, 150, 350, 82), _fill(J.teal));
        canvas.drawPath(_shape([0, 150, 350, 150], close: false), _line(J.ink));
        for (final wave in const [
          [30.0, 176.0],
          [210.0, 172.0],
          [110.0, 206.0],
          [270.0, 210.0],
        ]) {
          canvas.drawPath(
            Path()
              ..moveTo(wave[0], wave[1])
              ..quadraticBezierTo(
                wave[0] + 10,
                wave[1] - 8,
                wave[0] + 20,
                wave[1],
              )
              ..quadraticBezierTo(
                wave[0] + 30,
                wave[1] + 8,
                wave[0] + 40,
                wave[1],
              ),
            _line(J.white, 2.5),
          );
        }
        _solid(canvas, _shape([150, 72, 150, 158, 206, 158]), J.white);
        _solid(canvas, _shape([150, 92, 150, 158, 108, 158]), J.sunPale);
        _solid(canvas, _shape([92, 164, 222, 164, 204, 192, 110, 192]), J.sun);
        _solid(
          canvas,
          Path()
            ..moveTo(-6, 232)
            ..lineTo(-6, 176)
            ..quadraticBezierTo(22, 138, 58, 172)
            ..quadraticBezierTo(70, 200, 62, 232)
            ..close(),
          J.navy,
        );
      default:
        // The first screen: the road to the cave by day.
        canvas.drawCircle(const Offset(288, 142), 20, _fill(J.sun));
        canvas.drawCircle(const Offset(288, 142), 20, _line(J.ink));
        _solid(
          canvas,
          _shape([0, 230, 70, 152, 118, 200, 170, 128, 248, 230]),
          J.navy,
        );
        _solid(canvas, _shape([196, 230, 262, 170, 350, 230]), J.lilac);
        canvas.drawPath(_arch(146, 190, 230, 204), _fill(J.ink));
        canvas.drawPath(_arch(162, 178, 230, 212), _fill(J.sun));
        canvas.drawPath(
          _shape([12, 230, 338, 230], close: false),
          _line(J.ink),
        );
        _dots(
          canvas,
          Path()
            ..moveTo(214, 226)
            ..quadraticBezierTo(234, 212, 258, 222)
            ..quadraticBezierTo(282, 232, 308, 216),
          J.ink,
        );
    }
  }

  void _stars(Canvas canvas) {
    for (final star in const [
      [48.0, 40.0, 2.5],
      [118.0, 26.0, 2.0],
      [170.0, 58.0, 2.5],
      [226.0, 30.0, 2.0],
      [318.0, 70.0, 2.5],
      [86.0, 82.0, 2.0],
    ]) {
      canvas.drawCircle(Offset(star[0], star[1]), star[2], _fill(J.white));
    }
  }

  void _moon(Canvas canvas) {
    final moon = Path()
      ..moveTo(286, 26)
      ..arcToPoint(
        const Offset(300, 60),
        radius: const Radius.circular(20),
        largeArc: true,
        clockwise: false,
      )
      ..arcToPoint(const Offset(286, 26), radius: const Radius.circular(16))
      ..close();
    _solid(canvas, moon, J.sunPale);
  }

  void _palm(Canvas canvas, double x, double ground) {
    canvas.drawPath(
      Path()
        ..moveTo(x, ground)
        ..quadraticBezierTo(x + 4, ground - 30, x, ground - 58),
      _line(J.ink, 4),
    );
    for (final frond in const [
      [-26.0, -8.0],
      [-18.0, -26.0],
      [18.0, -26.0],
      [26.0, -8.0],
    ]) {
      canvas.drawPath(
        Path()
          ..moveTo(x, ground - 58)
          ..quadraticBezierTo(
            x + frond[0] * 0.6,
            ground - 58 + frond[1] - 8,
            x + frond[0],
            ground - 58 + frond[1] + 8,
          ),
        _line(J.right, 4),
      );
    }
  }

  @override
  bool shouldRepaint(_ScenePainter old) => old.art != art;
}

/// A small picture of a part of the surah, for its card on the map.
class SectionMark extends StatelessWidget {
  const SectionMark({super.key, required this.art, this.width = 76});

  /// book, cave, gardens, rain, sea or wall.
  final String art;
  final double width;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: Size(width, width * 60 / 76),
      painter: _MarkPainter(art),
    ),
  );
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter(this.art);

  final String art;

  @override
  void paint(Canvas canvas, Size size) {
    // Drawn in a box 76 wide and 60 high, standing on its bottom edge.
    canvas.scale(size.width / 76);
    switch (art) {
      case 'cave':
        _solid(
          canvas,
          _shape([2, 58, 28, 14, 44, 36, 56, 22, 74, 58]),
          J.lilac,
        );
        canvas.drawPath(_arch(28, 46, 58, 46), _fill(J.ink));
      case 'wall':
        _solid(canvas, _shape([2, 58, 17, 16, 32, 58]), J.lilac);
        _solid(canvas, _shape([44, 58, 59, 16, 74, 58]), J.lilac);
        for (final block in const [
          Rect.fromLTWH(24, 46, 14, 12),
          Rect.fromLTWH(38, 46, 14, 12),
          Rect.fromLTWH(26, 34, 12, 12),
          Rect.fromLTWH(38, 34, 12, 12),
        ]) {
          _solid(canvas, Path()..addRect(block), J.steel, width: 2.2);
        }
      case 'gardens':
        for (final tree in const [
          [24.0, 34.0, 13.0],
          [53.0, 29.0, 15.0],
        ]) {
          canvas.drawPath(
            _shape([tree[0], tree[1], tree[0], 58], close: false),
            _line(J.ink, 3),
          );
          _solid(
            canvas,
            Path()..addOval(
              Rect.fromCircle(
                center: Offset(tree[0], tree[1]),
                radius: tree[2],
              ),
            ),
            J.leaf,
          );
          for (final grape in const [
            Offset(-4, -3),
            Offset(4, -3),
            Offset(0, 4),
          ]) {
            canvas.drawCircle(
              Offset(tree[0], tree[1]) + grape,
              2.6,
              _fill(J.navy),
            );
          }
        }
        canvas.drawPath(_shape([4, 58, 72, 58], close: false), _line(J.ink));
      case 'rain':
        _solid(
          canvas,
          Path()
            ..moveTo(20, 34)
            ..arcToPoint(const Offset(27, 19), radius: const Radius.circular(8))
            ..arcToPoint(
              const Offset(49, 15),
              radius: const Radius.circular(12),
            )
            ..arcToPoint(
              const Offset(58, 34),
              radius: const Radius.circular(10),
            )
            ..close(),
          J.white,
        );
        for (var i = 0; i < 4; i++) {
          final x = 25.0 + i * 10;
          canvas.drawPath(
            _shape([x, 42, x - 4, 54], close: false),
            _line(J.tealSoft, 3),
          );
        }
      case 'sea':
        _solid(canvas, _shape([38, 8, 38, 36, 56, 36]), J.white);
        _solid(canvas, _shape([38, 16, 38, 36, 24, 36]), J.sunPale);
        _solid(canvas, _shape([14, 38, 62, 38, 54, 50, 22, 50]), J.sun);
        canvas.drawPath(
          Path()
            ..moveTo(6, 57)
            ..quadraticBezierTo(12, 52, 18, 57)
            ..quadraticBezierTo(24, 62, 30, 57)
            ..quadraticBezierTo(36, 52, 42, 57)
            ..quadraticBezierTo(48, 62, 54, 57)
            ..quadraticBezierTo(60, 52, 66, 57),
          _line(J.tealSoft, 3),
        );
      default:
        _solid(canvas, _shape([8, 46, 8, 16, 38, 22, 38, 54]), J.white);
        _solid(canvas, _shape([68, 46, 68, 16, 38, 22, 38, 54]), J.sunCream);
        for (var row = 0; row < 3; row++) {
          final y = 25.0 + row * 7;
          canvas.drawPath(
            _shape([14, y, 32, y + 4], close: false),
            _line(J.grey, 1.8),
          );
          canvas.drawPath(
            _shape([44, y + 4, 62, y], close: false),
            _line(J.grey, 1.8),
          );
        }
    }
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.art != art;
}

/// The lock on a part of the surah that has not opened yet.
class LockMark extends StatelessWidget {
  const LockMark({super.key, required this.label, this.size = 36});

  final String label;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: label,
    child: CustomPaint(size: Size.square(size), painter: const _LockPainter()),
  );
}

class _LockPainter extends CustomPainter {
  const _LockPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 36);
    canvas.drawPath(
      Path()
        ..moveTo(12, 16)
        ..lineTo(12, 12)
        ..arcToPoint(const Offset(24, 12), radius: const Radius.circular(6))
        ..lineTo(24, 16),
      _line(J.ink),
    );
    _solid(
      canvas,
      Path()..addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(8, 16, 20, 14),
          const Radius.circular(4),
        ),
      ),
      J.white,
    );
    canvas.drawCircle(const Offset(18, 23), 2, _fill(J.ink));
  }

  @override
  bool shouldRepaint(_LockPainter old) => false;
}

/// A big lit lantern with a glow, for the moment a stop is finished.
class LanternGlow extends StatelessWidget {
  const LanternGlow({super.key, this.size = 150});

  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: J.sunPale.withValues(alpha: 0.55),
            ),
          ),
          Container(
            margin: EdgeInsets.all(size * 0.13),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: J.sunPale,
            ),
          ),
          Lantern(state: LanternState.lit, size: size * 0.56),
        ],
      ),
    ),
  );
}
