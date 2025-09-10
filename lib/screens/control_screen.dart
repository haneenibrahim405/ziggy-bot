import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/control_service.dart';
import '../widgets/bottom_nav.dart';

class ControlScreen extends StatefulWidget {
  const ControlScreen({super.key});

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> {
  final ControlService _controlService = ControlService();
  String? activeDirection;

  Future<void> _handleCommand(String command) async {
    setState(() => activeDirection = command);
    await _controlService.sendCommand(command);
    if (mounted) {
      setState(() => activeDirection = null);
    }
  }

  Widget buildControlButton(String direction, IconData icon) {
    final bool isActive = activeDirection == direction;
    return Column(
      children: [
        GestureDetector(
          onTapDown: (_) => _handleCommand(direction),
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: isActive ? Colors.blue[400] : Colors.blue[100],
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive ? Colors.blue[800]! : Colors.blue[300]!,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                )
              ],
            ),
            child: Icon(
              icon,
              size: 50,
              color: isActive ? Colors.white : Colors.blue[800],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          direction.toUpperCase(),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: isActive ? Colors.blue[800] : Colors.grey[700],
          ),
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: const BottomNav(currentIndex: 1),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),
            Image.asset("assets/ziggy.png", height: 120),
            const SizedBox(height: 15),
            Text(
              "NAVIGATION",
              style: GoogleFonts.allertaStencil(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF231A4E),
              ),
            ),
            const SizedBox(height: 15),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  buildControlButton("forward", Icons.arrow_drop_up),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      buildControlButton("left", Icons.arrow_left),
                      const SizedBox(width: 140),
                      buildControlButton("right", Icons.arrow_right),
                    ],
                  ),
                  const SizedBox(height: 15),
                  buildControlButton("backward", Icons.arrow_drop_down),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
