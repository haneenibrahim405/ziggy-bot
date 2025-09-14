import 'dart:math';

class StepperMotorConverter {
  // Constants
  static const double STEPPER_CYCLE_LENGTH = 3.0; // 3cm per cycle
  static const double CANVAS_SIZE = 100.0; // 1 meter = 100cm

  /// Convert points to stepper motor commands (angles and steps)
  static List<Map<String, dynamic>> convertToStepperCommands(List<Map<String, dynamic>> points) {
    List<Map<String, dynamic>> stepperCommands = [];

    for (int i = 0; i < points.length - 1; i++) {
      Map<String, dynamic> currentPoint = points[i];
      Map<String, dynamic> nextPoint = points[i + 1];

      // Extract coordinates
      double x1 = currentPoint['x'].toDouble();
      double y1 = currentPoint['y'].toDouble();
      double x2 = nextPoint['x'].toDouble();
      double y2 = nextPoint['y'].toDouble();

      // Calculate distance between points
      double distance = _calculateDistance(x1, y1, x2, y2);

      // Calculate angle of the line
      double angle = _calculateAngle(x1, y1, x2, y2);

      // Calculate steps needed
      int steps = _calculateSteps(distance);

      // Scale coordinates for 1m x 1m canvas
      Map<String, double> scaledStart = _scaleToCanvas(x1, y1);
      Map<String, double> scaledEnd = _scaleToCanvas(x2, y2);

      stepperCommands.add({
        'fromPoint': {
          'x': scaledStart['x'],
          'y': scaledStart['y'],
          'original_x': x1,
          'original_y': y1,
        },
        'toPoint': {
          'x': scaledEnd['x'],
          'y': scaledEnd['y'],
          'original_x': x2,
          'original_y': y2,
        },
        'angle': angle.round(), // Angle in degrees
        'steps': steps,
        'distance': distance.round(), // Original distance in pixels/units
        'scaledDistance': _calculateDistance(scaledStart['x']!, scaledStart['y']!, scaledEnd['x']!, scaledEnd['y']!).round(),
        'penDown': nextPoint['penDown'] ?? true,
        'commandType': nextPoint['type'] ?? 'move',
      });
    }

    return stepperCommands;
  }

  /// Calculate distance between two points
  static double _calculateDistance(double x1, double y1, double x2, double y2) {
    return sqrt(pow(x2 - x1, 2) + pow(y2 - y1, 2));
  }

  /// Calculate angle of line between two points (in degrees)
  static double _calculateAngle(double x1, double y1, double x2, double y2) {
    double deltaX = x2 - x1;
    double deltaY = y2 - y1;

    // Calculate angle in radians, then convert to degrees
    double angleRadians = atan2(deltaY, deltaX);
    double angleDegrees = angleRadians * (180.0 / pi);

    // Normalize angle to 0-360 range
    if (angleDegrees < 0) {
      angleDegrees += 360;
    }

    return angleDegrees;
  }

  /// Calculate steps needed based on distance and stepper cycle length
  static int _calculateSteps(double distance) {
    return (distance / STEPPER_CYCLE_LENGTH).round();
  }

  /// Scale coordinates to fit 1m x 1m canvas (100cm x 100cm)
  static Map<String, double> _scaleToCanvas(double x, double y) {
    // Assuming input coordinates need to be scaled to fit the canvas
    // You might need to adjust this based on your original coordinate system
    return {
      'x': (x * CANVAS_SIZE / 1000).clamp(0, CANVAS_SIZE), // Adjust scale factor as needed
      'y': (y * CANVAS_SIZE / 1000).clamp(0, CANVAS_SIZE), // Adjust scale factor as needed
    };
  }

  /// Convert connected path to stepper commands
  static List<Map<String, dynamic>> convertConnectedPathToStepper(List<Map<String, dynamic>> connectedPath) {
    return convertToStepperCommands(connectedPath);
  }

  /// Updated ESP sending function with stepper commands
  static Map<String, dynamic> formatForESP(List<Map<String, dynamic>> stepperCommands) {
    return {
      'commands': stepperCommands,
      'totalCommands': stepperCommands.length,
      'canvasSize': CANVAS_SIZE,
      'stepperCycleLength': STEPPER_CYCLE_LENGTH,
      'type': 'stepper_commands',
    };
  }
}
