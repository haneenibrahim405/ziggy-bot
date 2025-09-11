import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/sketch.dart';

class PaintCanvas extends CustomPainter {
  List<Sketch> sketches;
  final double scale;
  final Offset offset;

  PaintCanvas({
    required this.scale,
    required this.offset,
    required this.sketches,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();

    canvas.translate(offset.dx, offset.dy);
    canvas.scale(scale);

    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = Colors.white
    );

    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()
          ..color = Colors.grey[300]!
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
    );

    for (Sketch sk in sketches) {
      if (sk.points.isEmpty) continue;

      Paint paint = Paint()
        ..color = sk.isEraser ? Colors.white : sk.strokeColor
        ..strokeWidth = sk.isEraser ? sk.estrokeSize : sk.strokeSize
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..isAntiAlias = true
        ..filterQuality = FilterQuality.high;

      if (sk.isEraser) {
        paint.color = Colors.white;
      }

      if (sk.brushmode == 1 || sk.isEraser) {
        Path path = Path();
        path.moveTo(sk.points[0].dx, sk.points[0].dy);

        for (int i = 1; i < sk.points.length; i++) {
          if (i < sk.points.length - 1) {
            final nextPoint = sk.points[i + 1];
            path.quadraticBezierTo(
              sk.points[i].dx,
              sk.points[i].dy,
              (sk.points[i].dx + nextPoint.dx) / 2,
              (sk.points[i].dy + nextPoint.dy) / 2,
            );
          } else {
            path.lineTo(sk.points[i].dx, sk.points[i].dy);
          }
        }
        canvas.drawPath(path, paint);
      } else {
        Offset p1 = sk.points[0];
        Offset p2 = sk.points[sk.points.length - 1];
        Rect rect = Rect.fromPoints(p1, p2);

        if (sk.brushmode == 2) {
          canvas.drawLine(p1, p2, paint);
        } else if (sk.brushmode == 3) {
          canvas.drawOval(rect, paint);
        } else {
          canvas.drawRect(rect, paint);
        }
      }
    }
    canvas.restore();
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}