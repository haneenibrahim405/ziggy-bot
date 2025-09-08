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
          Navigator.pushReplacementNamed(context, "/connection");
        } else if (index == 1) {
          Navigator.pushReplacementNamed(context, "/upload");
        }
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.power_settings_new), label: ""),
        BottomNavigationBarItem(icon: Icon(Icons.cloud_upload), label: ""),
      ],
    );
  }
}
