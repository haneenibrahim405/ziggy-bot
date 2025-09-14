import 'package:flutter/material.dart';
import 'dart:math' as math;

class DirectionModel {
  final String name;
  final double angle;
  final IconData icon;
  final Color? color;

  const DirectionModel({
    required this.name,
    required this.angle,
    required this.icon,
    this.color,
  });

  // الاتجاهات الأساسية الأربعة
  static const DirectionModel forward = DirectionModel(
    name: 'Forward',
    angle: 0,
    icon: Icons.keyboard_arrow_up,
    color: Colors.green,
  );

  static const DirectionModel right = DirectionModel(
    name: 'Right',
    angle: 90,
    icon: Icons.keyboard_arrow_right,
    color: Colors.blue,
  );

  static const DirectionModel backward = DirectionModel(
    name: 'Backward',
    angle: 180,
    icon: Icons.keyboard_arrow_down,
    color: Colors.orange,
  );

  static const DirectionModel left = DirectionModel(
    name: 'Left',
    angle: 270,
    icon: Icons.keyboard_arrow_left,
    color: Colors.purple,
  );

  // الاتجاهات المائلة
  static const DirectionModel forwardRight = DirectionModel(
    name: 'Forward-Right',
    angle: 45,
    icon: Icons.north_east,
  );

  static const DirectionModel backwardRight = DirectionModel(
    name: 'Back-Right',
    angle: 135,
    icon: Icons.south_east,
  );

  static const DirectionModel backwardLeft = DirectionModel(
    name: 'Back-Left',
    angle: 225,
    icon: Icons.south_west,
  );

  static const DirectionModel forwardLeft = DirectionModel(
    name: 'Forward-Left',
    angle: 315,
    icon: Icons.north_west,
  );

  // قائمة جميع الاتجاهات الثمانية
  static const List<DirectionModel> allDirections = [
    forward,
    forwardRight,
    right,
    backwardRight,
    backward,
    backwardLeft,
    left,
    forwardLeft,
  ];

  // تحويل الزاوية إلى راديان
  double get angleInRadians => angle * (math.pi / 180);

  // الحصول على الإحداثيات على الدائرة
  Offset getPositionOnCircle(double radius, Offset center) {
    final x = center.dx + radius * math.sin(angleInRadians);
    final y = center.dy - radius * math.cos(angleInRadians);
    return Offset(x, y);
  }

  // التحقق من كون هذا اتجاه أساسي (0, 90, 180, 270)
  bool get isPrimaryDirection => angle % 90 == 0;

  // الحصول على اللون المناسب للاتجاه
  Color getDirectionColor() {
    if (color != null) return color!;

    switch (angle.toInt()) {
      case 0: return Colors.green;      // Forward
      case 45: return Colors.teal;      // Forward-Right
      case 90: return Colors.blue;      // Right
      case 135: return Colors.indigo;   // Back-Right
      case 180: return Colors.orange;   // Backward
      case 225: return Colors.red;      // Back-Left
      case 270: return Colors.purple;   // Left
      case 315: return Colors.pink;     // Forward-Left
      default: return Colors.grey;
    }
  }

  @override
  String toString() => 'Direction: $name (${angle}°)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is DirectionModel &&
              runtimeType == other.runtimeType &&
              name == other.name &&
              angle == other.angle;

  @override
  int get hashCode => name.hashCode ^ angle.hashCode;
}

class DirectionHelper {

  static double angleDifference(double angle1, double angle2) {
    double diff = (angle1 - angle2).abs();
    if (diff > 180) diff = 360 - diff;
    return diff;
  }

  static DirectionModel findClosestDirection(double targetAngle, List<DirectionModel> directions) {
    DirectionModel closest = directions.first;
    double minDiff = angleDifference(targetAngle, closest.angle);

    for (DirectionModel direction in directions) {
      double diff = angleDifference(targetAngle, direction.angle);
      if (diff < minDiff) {
        minDiff = diff;
        closest = direction;
      }
    }
    return closest;
  }

  // تحويل إحداثيات اللمس إلى زاوية
  static double tapToAngle(Offset center, Offset tapPosition) {
    final dx = tapPosition.dx - center.dx;
    final dy = tapPosition.dy - center.dy;
    double angle = (math.atan2(dx, -dy) * 180 / math.pi + 360) % 360;
    return angle;
  }

  // التحقق من كون النقطة داخل الدائرة
  static bool isPointInCircle(Offset center, Offset point, double radius) {
    return (point - center).distance <= radius;
  }

  // تحويل أي زاوية إلى اسم الاتجاه المقابل
  static String angleToDirectionName(double angle) {
    // تحويل الزاوية لتكون في النطاق 0-360
    angle = angle % 360;
    if (angle < 0) angle += 360;

    if (angle >= 337.5 || angle < 22.5) return "Forward";
    if (angle >= 22.5 && angle < 67.5) return "Forward-Right";
    if (angle >= 67.5 && angle < 112.5) return "Right";
    if (angle >= 112.5 && angle < 157.5) return "Back-Right";
    if (angle >= 157.5 && angle < 202.5) return "Backward";
    if (angle >= 202.5 && angle < 247.5) return "Back-Left";
    if (angle >= 247.5 && angle < 292.5) return "Left";
    if (angle >= 292.5 && angle < 337.5) return "Forward-Left";
    return "Unknown";
  }

  // الحصول على لون ديناميكي للزاوية باستخدام HSV
  static Color getColorForAngle(double angle) {
    final hue = angle % 360;
    return HSVColor.fromAHSV(1.0, hue, 0.8, 0.9).toColor();
  }

  // تحويل الزاوية إلى اتجاه البوصلة (N, NE, E, etc.)
  static String angleToCompassDirection(double angle) {
    angle = angle % 360;
    if (angle < 0) angle += 360;

    if (angle >= 348.75 || angle < 11.25) return "N";
    if (angle >= 11.25 && angle < 33.75) return "NNE";
    if (angle >= 33.75 && angle < 56.25) return "NE";
    if (angle >= 56.25 && angle < 78.75) return "ENE";
    if (angle >= 78.75 && angle < 101.25) return "E";
    if (angle >= 101.25 && angle < 123.75) return "ESE";
    if (angle >= 123.75 && angle < 146.25) return "SE";
    if (angle >= 146.25 && angle < 168.75) return "SSE";
    if (angle >= 168.75 && angle < 191.25) return "S";
    if (angle >= 191.25 && angle < 213.75) return "SSW";
    if (angle >= 213.75 && angle < 236.25) return "SW";
    if (angle >= 236.25 && angle < 258.75) return "WSW";
    if (angle >= 258.75 && angle < 281.25) return "W";
    if (angle >= 281.25 && angle < 303.75) return "WNW";
    if (angle >= 303.75 && angle < 326.25) return "NW";
    if (angle >= 326.25 && angle < 348.75) return "NNW";
    return "N";
  }

  // تحقق من كون الزاوية قريبة من زاوية أخرى
  static bool isAngleNear(double angle1, double angle2, {double tolerance = 15.0}) {
    return angleDifference(angle1, angle2) <= tolerance;
  }

  // حساب الزاوية المتوسطة بين زاويتين
  static double averageAngle(double angle1, double angle2) {
    double diff = angleDifference(angle1, angle2);
    if (diff <= 180) {
      return (angle1 + angle2) / 2;
    } else {
      double avg = (angle1 + angle2 + 360) / 2;
      return avg % 360;
    }
  }

  // تدوير زاوية بمقدار معين
  static double rotateAngle(double angle, double rotation) {
    return (angle + rotation) % 360;
  }

  // حساب الاتجاه المعاكس
  static double oppositeAngle(double angle) {
    return (angle + 180) % 360;
  }
}

// فئة لحفظ حالة الاتجاه مع معلومات إضافية
class DirectionState {
  final double angle;
  final String directionName;
  final String compassDirection;
  final Color color;
  final DateTime timestamp;
  final bool isDrawingMode;

  DirectionState({
    required this.angle,
    required this.isDrawingMode,
  }) :
        directionName = DirectionHelper.angleToDirectionName(angle),
        compassDirection = DirectionHelper.angleToCompassDirection(angle),
        color = DirectionHelper.getColorForAngle(angle),
        timestamp = DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'angle': angle,
      'directionName': directionName,
      'compassDirection': compassDirection,
      'color': color.value,
      'timestamp': timestamp.toIso8601String(),
      'isDrawingMode': isDrawingMode,
    };
  }

  @override
  String toString() {
    return 'DirectionState(angle: ${angle.toInt()}°, direction: $directionName, compass: $compassDirection)';
  }
}