import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SplashScreen extends StatelessWidget {
  final Color containerColor = Color(0xFFE0E0E0);
  final Color chooseButtonColor = Color(0xFF231A4E);
  final Color uploadButtonColor = Color(0xFF231A4E);
  final Color iconColor = Color(0xFF231A4E);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset("assets/ziggy.png", height: 200),
            const SizedBox(height: 20),
            Text(
              "ZIGGY BOT",
              style: GoogleFonts.allertaStencil(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: iconColor,
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: 250,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacementNamed(context, "/connection");
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: uploadButtonColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  "Get Started",
                  style: GoogleFonts.allertaStencil(
                    fontSize: 18,
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}