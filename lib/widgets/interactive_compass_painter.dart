import 'package:flutter/material.dart';
import 'dart:math' as math;

class InteractiveCompassPainter extends CustomPainter {
  final double currentAngle;
  final bool isDragging;
  final bool isDrawingMode;

  InteractiveCompassPainter({
    required this.currentAngle,
    required this.isDragging,
    required this.isDrawingMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 20;

    _drawCompassBackground(canvas, center, radius);
    _drawAngleMarkers(canvas, center, radius);
    _drawMainDirections(canvas, center, radius);
    _drawCurrentAngle(canvas, center, radius);
    _drawCenterPoint(canvas, center);
    _drawDragIndicator(canvas, center, radius);
  }

  void _drawCompassBackground(Canvas canvas, Offset center, double radius) {
    // الخلفية الخارجية
    final outerRing = Paint()
      ..color = Colors.grey[200]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;
    canvas.drawCircle(center, radius + 4, outerRing);

    // الخلفية الأساسية
    final backgroundPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white,
          Colors.grey[50]!,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, backgroundPaint);

    // الحدود
    final borderPaint = Paint()
      ..color = isDragging ? Color(0xFF231A4E) : Colors.grey[300]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = isDragging ? 3 : 2;
    canvas.drawCircle(center, radius, borderPaint);

    // الدائرة الداخلية
    final innerCircle = Paint()
      ..color = Colors.grey[100]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, radius * 0.3, innerCircle);
  }

  void _drawAngleMarkers(Canvas canvas, Offset center, double radius) {
    for (int i = 0; i < 360; i += 5) {
      final angleRad = i * math.pi / 180;
      final isMainAngle = i % 30 == 0;
      final isMajorAngle = i % 90 == 0;

      final startRadius = radius * (isMajorAngle ? 0.85 : isMainAngle ? 0.9 : 0.95);
      final endRadius = radius * 0.98;

      final start = Offset(
        center.dx + startRadius * math.sin(angleRad),
        center.dy - startRadius * math.cos(angleRad),
      );
      final end = Offset(
        center.dx + endRadius * math.sin(angleRad),
        center.dy - endRadius * math.cos(angleRad),
      );

      final paint = Paint()
        ..color = isMajorAngle ? Colors.black87 : isMainAngle ? Colors.grey[600]! : Colors.grey[400]!
        ..strokeWidth = isMajorAngle ? 2.5 : isMainAngle ? 1.5 : 0.8;

      canvas.drawLine(start, end, paint);

      // رسم أرقام الزوايا الرئيسية
      if (isMajorAngle) {
        _drawAngleText(canvas, center, radius * 0.75, i, "$i°");
      }
    }
  }

  void _drawMainDirections(Canvas canvas, Offset center, double radius) {
    final directions = [
      {'angle': 0, 'text': 'N', 'icon': Icons.keyboard_arrow_up},
      {'angle': 45, 'text': 'NE', 'icon': Icons.north_east},
      {'angle': 90, 'text': 'E', 'icon': Icons.keyboard_arrow_right},
      {'angle': 135, 'text': 'SE', 'icon': Icons.south_east},
      {'angle': 180, 'text': 'S', 'icon': Icons.keyboard_arrow_down},
      {'angle': 225, 'text': 'SW', 'icon': Icons.south_west},
      {'angle': 270, 'text': 'W', 'icon': Icons.keyboard_arrow_left},
      {'angle': 315, 'text': 'NW', 'icon': Icons.north_west},
    ];

    for (final direction in directions) {
      final angle = direction['angle'] as int;
      final text = direction['text'] as String;
      final icon = direction['icon'] as IconData;
      final isMainDirection = angle % 90 == 0;

      // رسم أيقونة الاتجاه
      _drawDirectionIcon(canvas, center, radius * 0.6, angle.toDouble(), icon, isMainDirection);

      // رسم نص الاتجاه للاتجاهات الرئيسية
      if (isMainDirection) {
        _drawAngleText(canvas, center, radius * 0.45, angle, text);
      }
    }
  }

  void _drawDirectionIcon(Canvas canvas, Offset center, double radius, double angle, IconData icon, bool isMain) {
    final angleRad = angle * math.pi / 180;
    final position = Offset(
      center.dx + radius * math.sin(angleRad),
      center.dy - radius * math.cos(angleRad),
    );

    final iconPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: isMain ? 22 : 16,
          fontFamily: icon.fontFamily,
          color: _isNearCurrentAngle(angle) ? Colors.white :
          isMain ? Color(0xFF231A4E) : Colors.grey[600],
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    iconPainter.layout();
    iconPainter.paint(
      canvas,
      Offset(
        position.dx - iconPainter.width / 2,
        position.dy - iconPainter.height / 2,
      ),
    );
  }

  void _drawAngleText(Canvas canvas, Offset center, double radius, int angle, String text) {
    final angleRad = angle * math.pi / 180;
    final position = Offset(
      center.dx + radius * math.sin(angleRad),
      center.dy - radius * math.cos(angleRad),
    );

    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 12,
          color: _isNearCurrentAngle(angle.toDouble()) ? Colors.white : Colors.grey[700],
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        position.dx - textPainter.width / 2,
        position.dy - textPainter.height / 2,
      ),
    );
  }

  void _drawCurrentAngle(Canvas canvas, Offset center, double radius) {
    final angleRad = currentAngle * math.pi / 180;

    // رسم قطاع الزاوية المحددة
    final sectorPaint = Paint()
      ..color = _getAngleColor(currentAngle).withOpacity(0.6)
      ..style = PaintingStyle.fill;

    final sectorPath = Path();
    sectorPath.moveTo(center.dx, center.dy);
    sectorPath.arcTo(
      Rect.fromCircle(center: center, radius: radius * 0.8),
      (currentAngle - 15) * math.pi / 180 - math.pi / 2,
      30 * math.pi / 180,
      false,
    );
    sectorPath.close();
    canvas.drawPath(sectorPath, sectorPaint);

    // رسم خط الاتجاه
    final lineEnd = Offset(
      center.dx + (radius * 0.7) * math.sin(angleRad),
      center.dy - (radius * 0.7) * math.cos(angleRad),
    );

    final linePaint = Paint()
      ..color = _getAngleColor(currentAngle)
      ..strokeWidth = isDragging ? 4 : 3
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(center, lineEnd, linePaint);

    // رسم سهم في النهاية
    _drawArrow(canvas, center, lineEnd, linePaint);

    // رسم دائرة في نهاية الخط
    final endCirclePaint = Paint()
      ..color = _getAngleColor(currentAngle)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(lineEnd, isDragging ? 8 : 6, endCirclePaint);

    final endCircleBorder = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(lineEnd, isDragging ? 4 : 3, endCircleBorder);
  }

  void _drawArrow(Canvas canvas, Offset start, Offset end, Paint paint) {
    const arrowSize = 12.0;
    final direction = (end - start);
    final unitVector = direction / direction.distance;

    final arrowPoint1 = end - unitVector * arrowSize +
        Offset(-unitVector.dy, unitVector.dx) * arrowSize * 0.4;
    final arrowPoint2 = end - unitVector * arrowSize +
        Offset(unitVector.dy, -unitVector.dx) * arrowSize * 0.4;

    final arrowPath = Path();
    arrowPath.moveTo(end.dx, end.dy);
    arrowPath.lineTo(arrowPoint1.dx, arrowPoint1.dy);
    arrowPath.lineTo(arrowPoint2.dx, arrowPoint2.dy);
    arrowPath.close();

    final arrowPaint = Paint()
      ..color = paint.color
      ..style = PaintingStyle.fill;

    canvas.drawPath(arrowPath, arrowPaint);
  }

  void _drawCenterPoint(Canvas canvas, Offset center) {
    // النقطة المركزية
    final centerPaint = Paint()
      ..color = isDragging ? _getAngleColor(currentAngle) : Color(0xFF231A4E)
      ..style = PaintingStyle.fill;

    final centerRadius = isDragging ? 10.0 : 8.0;
    canvas.drawCircle(center, centerRadius, centerPaint);

    // نقطة بيضاء داخلية
    final innerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, centerRadius * 0.4, innerPaint);

    // رسم رمز الوضع
    final iconPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(isDrawingMode ? Icons.edit.codePoint : Icons.navigation.codePoint),
        style: TextStyle(
          fontSize: 12,
          fontFamily: Icons.edit.fontFamily,
          color: isDragging ? _getAngleColor(currentAngle) : Color(0xFF231A4E),
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    iconPainter.layout();
    iconPainter.paint(
      canvas,
      Offset(
        center.dx - iconPainter.width / 2,
        center.dy - iconPainter.height / 2,
      ),
    );
  }

  void _drawDragIndicator(Canvas canvas, Offset center, double radius) {
    if (!isDragging) return;

    // تأثير الموجة المتحركة
    for (int i = 0; i < 3; i++) {
      final waveRadius = radius + (i * 15) + 10;
      final wavePaint = Paint()
        ..color = _getAngleColor(currentAngle).withOpacity(0.3 - (i * 0.1))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      canvas.drawCircle(center, waveRadius, wavePaint);
    }
  }

  Color _getAngleColor(double angle) {
    final hue = angle;
    return HSVColor.fromAHSV(1.0, hue, 0.8, 0.9).toColor();
  }

  bool _isNearCurrentAngle(double angle) {
    final diff = (currentAngle - angle).abs();
    final normalizedDiff = diff > 180 ? 360 - diff : diff;
    return normalizedDiff < 20;
  }

  @override
  bool shouldRepaint(InteractiveCompassPainter oldDelegate) {
    return oldDelegate.currentAngle != currentAngle ||
        oldDelegate.isDragging != isDragging ||
        oldDelegate.isDrawingMode != isDrawingMode;
  }
}