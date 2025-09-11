import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import '../widgets/bottom_nav.dart';
import '../widgets/interactive_compass_painter.dart';

class CompassControlScreen extends StatefulWidget {
  const CompassControlScreen({super.key});

  @override
  State<CompassControlScreen> createState() => _CompassControlScreenState();
}

class _CompassControlScreenState extends State<CompassControlScreen>
    with SingleTickerProviderStateMixin {

  double currentAngle = 0.0;
  bool isDragging = false;
  bool isDrawingEnabled = false;

  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  double _calculateAngle(Offset center, Offset position) {
    final dx = position.dx - center.dx;
    final dy = position.dy - center.dy;
    double angle = (math.atan2(dx, -dy) * 180 / math.pi + 360) % 360;
    return angle;
  }

  // التحقق من أن النقطة داخل الدائرة
  bool _isPointInCircle(Offset center, Offset point, double radius) {
    return (point - center).distance <= radius;
  }

  void _handlePanStart(DragStartDetails details, Size compassSize, Offset center) {
    final tapPosition = details.localPosition;
    final radius = compassSize.width / 2 - 20;

    if (_isPointInCircle(center, tapPosition, radius)) {
      setState(() {
        isDragging = true;
        currentAngle = _calculateAngle(center, tapPosition);
      });
      _animationController.forward();
      _sendCommand(currentAngle);
    }
  }

  void _handlePanUpdate(DragUpdateDetails details, Size compassSize, Offset center) {
    if (!isDragging) return;

    final position = details.localPosition;
    final radius = compassSize.width / 2 - 20;

    if (_isPointInCircle(center, position, radius)) {
      setState(() {
        currentAngle = _calculateAngle(center, position);
      });
      _sendCommand(currentAngle);
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    setState(() {
      isDragging = false;
    });
    _animationController.reverse();
    _stopRobot();
  }

  Future<void> _sendCommand(double angle) async {
    String action = isDrawingEnabled ? "move and draw" : "move only";
    print('Robot command: ${action} at angle: ${angle.toInt()}°');

    // هنا يتم إرسال الأمر للروبوت
    // await RobotController.moveToAngle(angle, shouldDraw: isDrawingEnabled);
  }

  Future<void> _stopRobot() async {
    print('Stopping robot movement');
    // await RobotController.stop();
  }

  String _getDirectionName(double angle) {
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

  Color _getAngleColor(double angle) {
    final hue = angle;
    return HSVColor.fromAHSV(1.0, hue, 0.8, 0.9).toColor();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: const BottomNav(currentIndex: 1),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildControlOptions(),
            Expanded(
              child: _buildInteractiveCompass(),
            ),
            _buildAngleInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Image.asset("assets/ziggy.png", height: 80),
          const SizedBox(height: 10),
          Text(
            "INTERACTIVE COMPASS",
            style: GoogleFonts.audiowide(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF231A4E),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlOptions() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "Robot Mode:",
            style: GoogleFonts.audiowide(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF231A4E),
            ),
          ),
          Row(
            children: [
              Icon(
                Icons.directions_walk,
                color: Colors.blue[600],
                size: 20,
              ),
              const SizedBox(width: 5),
              Text(
                "Move",
                style: GoogleFonts.audiowide(
                  fontSize: 12,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(width: 10),
              Transform.scale(
                scale: 0.8,
                child: Switch(
                  value: isDrawingEnabled,
                  onChanged: (value) {
                    setState(() {
                      isDrawingEnabled = value;
                    });
                  },
                  activeColor: Colors.green[600],
                  inactiveThumbColor: Colors.blue[600],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                Icons.edit,
                color: Colors.green[600],
                size: 20,
              ),
              const SizedBox(width: 5),
              Text(
                "Draw",
                style: GoogleFonts.audiowide(
                  fontSize: 12,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveCompass() {
    return Center(
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: isDragging ? _pulseAnimation.value : 1.0,
            child: Container(
              width: 300,
              height: 300,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = Size(constraints.maxWidth, constraints.maxHeight);
                  final center = Offset(size.width / 2, size.height / 2);

                  return GestureDetector(
                    onPanStart: (details) => _handlePanStart(details, size, center),
                    onPanUpdate: (details) => _handlePanUpdate(details, size, center),
                    onPanEnd: _handlePanEnd,
                    child: CustomPaint(
                      painter: InteractiveCompassPainter(
                        currentAngle: currentAngle,
                        isDragging: isDragging,
                        isDrawingMode: isDrawingEnabled,
                      ),
                      size: size,
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAngleInfo() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // مؤشر الزاوية الحالية
          Container(
            padding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _getAngleColor(currentAngle).withOpacity(0.8),
                  _getAngleColor(currentAngle).withOpacity(0.6),
                ],
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: _getAngleColor(currentAngle).withOpacity(0.3),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getDirectionName(currentAngle),
                      style: GoogleFonts.audiowide(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      "${currentAngle.toInt()}°",
                      style: GoogleFonts.audiowide(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isDrawingEnabled ? Icons.edit : Icons.navigation,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 15),

          Row(
            children: [
              Expanded(
                child: _buildInfoCard(
                  "Status",
                  isDragging ? "Moving" : "Stopped",
                  isDragging ? Colors.green : Colors.grey,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildInfoCard(
                  "Mode",
                  isDrawingEnabled ? "Move + Draw" : "Move Only",
                  isDrawingEnabled ? Colors.orange : Colors.blue,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, String value, Color color) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: GoogleFonts.audiowide(
              fontSize: 10,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.audiowide(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}