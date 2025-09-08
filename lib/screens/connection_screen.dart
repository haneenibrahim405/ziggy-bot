import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/bottom_nav.dart';

class ConnectionScreen extends StatefulWidget {
  @override
  _ConnectionScreenState createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  bool isOn = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        bottomNavigationBar: BottomNav(currentIndex: 0),
        body: SafeArea(
          bottom: false,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset("assets/ziggy.png", height: 150),
                const SizedBox(height: 30),
                Text(
                  "Connection is ${isOn ? "ON" : "OFF"}",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: isOn ? Colors.green : Colors.red,
                  ),
                ),
                const SizedBox(height: 30),

                GestureDetector(
                  onTap: () {
                    setState(() {
                      isOn = !isOn;
                    });
                  },
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    width: 120,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      color: isOn ? Colors.green : Colors.grey[300],
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        )
                      ],
                    ),
                    child: Stack(
                      children: [
                        if (isOn)
                          Positioned(
                            left: 15,
                            top: 20,
                            child: Text(
                              "ON",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          )
                        else
                          Positioned(
                            right: 15,
                            top: 20,
                            child: Text(
                              "OFF",
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),

                        AnimatedPositioned(
                          duration: Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          left: isOn ? 60 : 4,
                          top: 4,
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 5,
                                  offset: Offset(0, 2),
                                )
                              ],
                            ),
                            child: Icon(
                              isOn ? Icons.check : Icons.close,
                              color: isOn ? Colors.green : Colors.red,
                              size: 28,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "Tap to ${isOn ? "disconnect" : "connect"}",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}