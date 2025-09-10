import 'package:flutter/material.dart';

class BottomNav extends StatelessWidget {
  final int currentIndex;
  const BottomNav({required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      backgroundColor: Colors.white,
      currentIndex: currentIndex,
      onTap: (index) {
        if (index == 0) {
          Navigator.pushReplacementNamed(context, "/upload");
        } else if (index == 1) {
          Navigator.pushReplacementNamed(context, "/control");
        }
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.cloud_upload), label: ""),
        BottomNavigationBarItem(icon: Icon(Icons.gamepad), label: ""),
      ],
    );
  }
}
