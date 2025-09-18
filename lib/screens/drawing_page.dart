import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import '../models/sketch.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/paint_canvas.dart';
import '../service/server_service.dart';

class DrawingPage extends StatefulWidget {
  const DrawingPage({super.key});

  @override
  State<DrawingPage> createState() => _DrawingPageState();
}

class _DrawingPageState extends State<DrawingPage> {
  List<Sketch> sketches = [];
  List<Offset> currentPoints = [];
  GlobalKey repaintKey = GlobalKey();
  Color currentColor = Colors.black;
  double currentStrokeSize = 4.0;
  int currentBrushMode = 1;
  bool isEraserMode = false;

  // Server processing variables
  bool isProcessing = false;
  bool isSendingToRobot = false;
  String? statusMessage;
  ServerProcessingResult? serverResult;
  RobotSendResult? robotResult;

  // Scale control
  double drawingScale = 1.0;

  // Connection status
  bool isServerConnected = false;
  bool isESPConnected = false;

  @override
  void initState() {
    super.initState();
    _checkConnections();
  }

  /// Check server and ESP connections
  Future<void> _checkConnections() async {
    setState(() {
      statusMessage = "Checking connections...";
    });

    bool serverConnected = await ServerService.checkServerConnection();
    bool espConnected = await ServerService.checkESPConnection();

    setState(() {
      isServerConnected = serverConnected;
      isESPConnected = espConnected;
      statusMessage = _getConnectionStatus();
    });
  }

  String _getConnectionStatus() {
    if (isServerConnected && isESPConnected) {
      return "✅ Server & ESP32 connected - Ready to process!";
    } else if (isServerConnected && !isESPConnected) {
      return "⚠️ Server connected, ESP32 disconnected";
    } else if (!isServerConnected && isESPConnected) {
      return "⚠️ ESP32 connected, Server disconnected";
    } else {
      return "❌ Both Server & ESP32 disconnected";
    }
  }

  Future<File?> saveDrawing() async {
    try {
      RenderRepaintBoundary boundary = repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 5.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) return null;

      Uint8List pngBytes = byteData.buffer.asUint8List();

      // Check if canvas is empty
      final pixels = byteData.buffer.asUint32List();
      bool isWhite = pixels.every((color) => color == 0xFFFFFFFF);
      if (isWhite) return null;

      final directory = await getApplicationDocumentsDirectory();
      String fileName = 'drawing_${DateTime.now().millisecondsSinceEpoch}.png';
      File imgFile = File('${directory.path}/$fileName');
      await imgFile.writeAsBytes(pngBytes);

      return imgFile;
    } catch (e) {
      print("Error saving drawing: $e");
      return null;
    }
  }

  /// NEW: Send drawing directly to robot with GRBL commands
  Future<void> sendDrawingToRobot() async {
    if (sketches.isEmpty) {
      setState(() {
        statusMessage = "Canvas is empty! Please draw something first.";
      });
      return;
    }

    if (!isServerConnected) {
      setState(() {
        statusMessage = "Server not connected! Check connection first.";
      });
      return;
    }

    setState(() {
      isSendingToRobot = true;
      statusMessage = "🤖 Processing drawing and sending GRBL commands to robot with ${drawingScale}x scale...";
      robotResult = null;
    });

    try {
      File? imageFile = await saveDrawing();
      if (imageFile == null) {
        throw Exception("Failed to save drawing");
      }

      RobotSendResult result = await ServerService.sendImageToRobot(
        imageFile,
        scale: drawingScale,
      );

      setState(() {
        isSendingToRobot = false;
        robotResult = result;

        if (result.success) {
          statusMessage = "🎉 SUCCESS! Robot received ${result.totalCommands} GRBL commands with ${result.appliedScale}x scale. Drawing should start now!";
        } else {
          statusMessage = "❌ Failed to send to robot: ${result.error}";
        }
      });

    } catch (e) {
      setState(() {
        isSendingToRobot = false;
        statusMessage = "💥 Robot processing error: ${e.toString()}";
      });
    }
  }

  /// Process drawing using server (legacy method)
  Future<void> processDrawingOnServer() async {
    if (sketches.isEmpty) {
      setState(() {
        statusMessage = "Canvas is empty! Please draw something first.";
      });
      return;
    }

    if (!isServerConnected) {
      setState(() {
        statusMessage = "Server not connected! Check connection first.";
      });
      return;
    }

    setState(() {
      isProcessing = true;
      statusMessage = "🔄 Processing drawing on server...";
      serverResult = null;
    });

    try {
      File? imageFile = await saveDrawing();
      if (imageFile == null) {
        throw Exception("Failed to save drawing");
      }

      ServerProcessingResult result = await ServerService.processImageOnServer(imageFile);

      setState(() {
        isProcessing = false;
        serverResult = result;

        if (result.success) {
          statusMessage = "✅ ${result.message} - Found ${result.totalStrokes ?? 0} strokes with ${result.totalPoints ?? 0} points";
        } else {
          statusMessage = "❌ ${result.error}";
        }
      });

    } catch (e) {
      setState(() {
        isProcessing = false;
        statusMessage = "💥 Processing error: ${e.toString()}";
      });
    }
  }

  /// Send bulk data to robot (legacy method - deprecated)
  @deprecated
  Future<void> sendBulkToRobot() async {
    if (serverResult == null || !serverResult!.success) {
      setState(() {
        statusMessage = "No processed data available. Process drawing first.";
      });
      return;
    }

    if (!isESPConnected) {
      setState(() {
        statusMessage = "ESP32 not connected! Check connection first.";
      });
      return;
    }

    setState(() {
      isSendingToRobot = true;
      statusMessage = "🚀 Sending bulk data to robot with ${drawingScale}x scale...";
    });

    try {
      // Note: This method is deprecated - use sendDrawingToRobot() instead
      setState(() {
        isSendingToRobot = false;
        statusMessage = "⚠️ This method is deprecated. Use 'Send to Robot' for GRBL commands.";
      });

    } catch (e) {
      setState(() {
        isSendingToRobot = false;
        statusMessage = "💥 Robot send error: ${e.toString()}";
      });
    }
  }

  void clearCanvas() {
    setState(() {
      sketches.clear();
      serverResult = null;
      robotResult = null;
      statusMessage = null;
      drawingScale = 1.0;
    });
  }

  void undoLast() {
    if (sketches.isNotEmpty) {
      setState(() {
        sketches.removeLast();
      });
    }
  }

  String _getEstimatedDrawingSize() {
    int totalCommands = 0;

    if (robotResult?.totalCommands != null) {
      totalCommands = robotResult!.totalCommands!;
    } else if (serverResult?.totalPoints != null) {
      totalCommands = serverResult!.totalPoints!;
    }

    if (totalCommands == 0) return "N/A";

    double estimatedSizeCm = (totalCommands * 0.3) * drawingScale; // Estimate: each command = 0.3 cm

    if (estimatedSizeCm < 100) {
      return "${estimatedSizeCm.toStringAsFixed(1)} cm";
    } else {
      return "${(estimatedSizeCm / 100).toStringAsFixed(2)} m";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height,
          ),
          child: Column(
            children: [
              // App bar with connection status
              Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 16,
                  left: 20,
                  right: 20,
                  bottom: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    )
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.smart_toy, color: Colors.blue.shade700, size: 28),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "Drawing Canvas (GRBL Robot)",
                            style: GoogleFonts.audiowide(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: _checkConnections,
                          child: Container(
                            padding: EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Icon(
                              Icons.refresh,
                              color: Colors.blue.shade700,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Server Status
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isServerConnected ? Colors.green.shade50 : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: isServerConnected ? Colors.green : Colors.red,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isServerConnected ? Icons.cloud_done : Icons.cloud_off,
                                color: isServerConnected ? Colors.green : Colors.red,
                                size: 14,
                              ),
                              SizedBox(width: 4),
                              Text(
                                "Server",
                                style: GoogleFonts.audiowide(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isServerConnected ? Colors.green.shade700 : Colors.red.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 12),
                        // ESP32 Status
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isESPConnected ? Colors.green.shade50 : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: isESPConnected ? Colors.green : Colors.red,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isESPConnected ? Icons.wifi : Icons.wifi_off,
                                color: isESPConnected ? Colors.green : Colors.red,
                                size: 14,
                              ),
                              SizedBox(width: 4),
                              Text(
                                "ESP32",
                                style: GoogleFonts.audiowide(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isESPConnected ? Colors.green.shade700 : Colors.red.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Tools
              Container(
                padding: EdgeInsets.all(16),
                color: Colors.white,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Drawing tools
                      _buildTool(Icons.brush, !isEraserMode && currentBrushMode == 1, () {
                        setState(() { isEraserMode = false; currentBrushMode = 1; });
                      }),
                      SizedBox(width: 8),
                      _buildTool(Icons.auto_delete, isEraserMode, () {
                        setState(() { isEraserMode = true; });
                      }),
                      SizedBox(width: 8),
                      _buildTool(Icons.horizontal_rule, !isEraserMode && currentBrushMode == 2, () {
                        setState(() { isEraserMode = false; currentBrushMode = 2; });
                      }),

                      SizedBox(width: 20),

                      // Color picker
                      GestureDetector(
                        onTap: () => _showColorPicker(),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: currentColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),

                      // Undo
                      IconButton(
                        onPressed: undoLast,
                        icon: Icon(Icons.undo),
                      ),

                      // Clear
                      IconButton(
                        onPressed: clearCanvas,
                        icon: Icon(Icons.clear),
                      ),
                    ],
                  ),
                ),
              ),

              // Canvas and Results
              Container(
                height: MediaQuery.of(context).size.height - 280,
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Drawing Canvas
                    Expanded(
                      flex: 3,
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 6,
                              offset: Offset(0, 3),
                            )
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: GestureDetector(
                            onPanStart: (details) {
                              setState(() {
                                currentPoints = [details.localPosition];
                                sketches.add(Sketch(
                                  points: currentPoints,
                                  strokeColor: currentColor,
                                  strokeSize: currentStrokeSize,
                                  estrokeSize: 20.0,
                                  isEraser: isEraserMode,
                                  brushmode: currentBrushMode,
                                  id: DateTime.now().toString(),
                                ));
                              });
                            },
                            onPanUpdate: (details) {
                              setState(() {
                                currentPoints.add(details.localPosition);
                              });
                            },
                            onPanEnd: (details) {
                              setState(() {
                                currentPoints = [];
                              });
                            },
                            child: RepaintBoundary(
                              key: repaintKey,
                              child: Container(
                                color: Colors.white,
                                child: CustomPaint(
                                  painter: PaintCanvas(
                                    scale: 1.0,
                                    offset: Offset.zero,
                                    sketches: sketches,
                                  ),
                                  size: Size.infinite,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 16),

                    // Processed Image Display
                    Expanded(
                      flex: 2,
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 6,
                              offset: Offset(0, 3),
                            )
                          ],
                        ),
                        child: Column(
                          children: [
                            // Header
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: robotResult?.success == true
                                    ? Colors.green.shade50
                                    : serverResult?.success == true
                                    ? Colors.blue.shade50
                                    : Colors.grey.shade50,
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(12),
                                  topRight: Radius.circular(12),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    robotResult?.success == true
                                        ? Icons.smart_toy
                                        : serverResult?.success == true
                                        ? Icons.cloud_done
                                        : Icons.cloud_upload,
                                    color: robotResult?.success == true
                                        ? Colors.green.shade700
                                        : serverResult?.success == true
                                        ? Colors.blue.shade700
                                        : Colors.grey.shade600,
                                    size: 16,
                                  ),
                                  SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      robotResult?.success == true
                                          ? "Robot GRBL Processed"
                                          : serverResult?.success == true
                                          ? "Server Processed Image"
                                          : "Processed Image Preview",
                                      style: GoogleFonts.audiowide(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: robotResult?.success == true
                                            ? Colors.green.shade700
                                            : serverResult?.success == true
                                            ? Colors.blue.shade700
                                            : Colors.grey.shade600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Image Area
                            Expanded(
                              child: Container(
                                width: double.infinity,
                                padding: EdgeInsets.all(8),
                                child: robotResult?.processedImageBase64 != null
                                    ? ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.memory(
                                    base64Decode(robotResult!.processedImageBase64!),
                                    fit: BoxFit.contain,
                                    width: double.infinity,
                                    height: double.infinity,
                                  ),
                                )
                                    : serverResult?.processedImageBase64 != null
                                    ? ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.memory(
                                    base64Decode(serverResult!.processedImageBase64!),
                                    fit: BoxFit.contain,
                                    width: double.infinity,
                                    height: double.infinity,
                                  ),
                                )
                                    : Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.smart_toy,
                                        size: 24,
                                        color: Colors.grey.shade400,
                                      ),
                                      SizedBox(height: 6),
                                      Text(
                                        "Processed image will appear here",
                                        style: GoogleFonts.audiowide(
                                          color: Colors.grey.shade600,
                                          fontSize: 10,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Scale Control (always show when we have sketches)
              if (sketches.isNotEmpty) ...[
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 16),
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.purple.shade300),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.zoom_in, color: Colors.purple.shade700, size: 16),
                          SizedBox(width: 6),
                          Text(
                            "Drawing Scale: ${drawingScale.toStringAsFixed(1)}x",
                            style: GoogleFonts.audiowide(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.purple.shade700,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Text("0.5x", style: GoogleFonts.audiowide(fontSize: 10, color: Colors.purple.shade600)),
                          Expanded(
                            child: Slider(
                              value: drawingScale,
                              min: 0.5,
                              max: 3.0,
                              divisions: 25,
                              activeColor: Colors.purple.shade600,
                              inactiveColor: Colors.purple.shade200,
                              onChanged: (isProcessing || isSendingToRobot) ? null : (value) {
                                setState(() {
                                  drawingScale = value;
                                });
                              },
                            ),
                          ),
                          Text("3x", style: GoogleFonts.audiowide(fontSize: 10, color: Colors.purple.shade600)),
                        ],
                      ),
                      Text(
                        "Est. Size: ${_getEstimatedDrawingSize()}",
                        style: GoogleFonts.audiowide(
                          fontSize: 12,
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
              ],

              // Action Buttons
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  children: [
                    // PRIMARY: Send to Robot Button (GRBL)
                    if (sketches.isNotEmpty) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: (isSendingToRobot || isProcessing || !isServerConnected)
                              ? null : sendDrawingToRobot,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: (isServerConnected && !isSendingToRobot && !isProcessing)
                                ? Colors.green.shade600
                                : Colors.grey,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                          child: isSendingToRobot
                              ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                              SizedBox(width: 10),
                              Text("Sending to Robot...", style: GoogleFonts.audiowide(fontSize: 16)),
                            ],
                          )
                              : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.smart_toy, color: Colors.white, size: 24),
                              SizedBox(width: 10),
                              Text(
                                  isServerConnected
                                      ? "Send to Robot (GRBL)"
                                      : "Server not connected",
                                  style: GoogleFonts.audiowide(fontSize: 16, fontWeight: FontWeight.bold)
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 12),
                    ],

                    // SECONDARY: Process Only Button
                    SizedBox(
                      width: double.infinity,
                      height: 45,
                      child: ElevatedButton(
                        onPressed: (isProcessing || sketches.isEmpty || !isServerConnected || isSendingToRobot)
                            ? null : processDrawingOnServer,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: (isServerConnected && !isProcessing && !isSendingToRobot)
                              ? Colors.blue.shade600
                              : Colors.grey,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                        ),
                        child: isProcessing
                            ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                            SizedBox(width: 8),
                            Text("Processing on Server...", style: GoogleFonts.audiowide(fontSize: 14)),
                          ],
                        )
                            : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.cloud_upload, color: Colors.white, size: 18),
                            SizedBox(width: 8),
                            Text(
                                isServerConnected ? "Process Only" : "Server not connected",
                                style: GoogleFonts.audiowide(fontSize: 14)
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Robot Results Display (NEW)
              if (robotResult?.success == true && robotResult?.stats != null) ...[
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 16),
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade300),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.smart_toy, color: Colors.green.shade700, size: 20),
                          SizedBox(width: 8),
                          Text(
                            "Robot GRBL Results",
                            style: GoogleFonts.audiowide(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              Text(
                                "${robotResult?.stats?['original_strokes'] ?? 0}",
                                style: GoogleFonts.audiowide(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                              Text(
                                "Original",
                                style: GoogleFonts.audiowide(fontSize: 11, color: Colors.orange.shade600),
                              ),
                            ],
                          ),
                          Icon(Icons.arrow_forward, color: Colors.grey.shade600, size: 18),
                          Column(
                            children: [
                              Text(
                                "${robotResult?.totalCommands ?? 0}",
                                style: GoogleFonts.audiowide(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade700,
                                ),
                              ),
                              Text(
                                "GRBL Cmds",
                                style: GoogleFonts.audiowide(fontSize: 11, color: Colors.green.shade600),
                              ),
                            ],
                          ),
                          Icon(Icons.arrow_forward, color: Colors.grey.shade600, size: 18),
                          Column(
                            children: [
                              Text(
                                "${robotResult?.appliedScale?.toStringAsFixed(1) ?? '1.0'}x",
                                style: GoogleFonts.audiowide(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple.shade700,
                                ),
                              ),
                              Text(
                                "Scale",
                                style: GoogleFonts.audiowide(fontSize: 11, color: Colors.purple.shade600),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
              ],

              // Server Results Display (legacy)
              if (serverResult?.success == true && serverResult?.stats != null) ...[
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 16),
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade300),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.analytics, color: Colors.blue.shade700, size: 18),
                          SizedBox(width: 8),
                          Text(
                            "Server Processing Results",
                            style: GoogleFonts.audiowide(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700),
                          ),
                        ],
                      ),
                      SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              Text(
                                "${serverResult?.stats?['original_strokes'] ?? 0}",
                                style: GoogleFonts.audiowide(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                              Text(
                                "Original",
                                style: GoogleFonts.audiowide(fontSize: 10, color: Colors.orange.shade600),
                              ),
                            ],
                          ),
                          Icon(Icons.arrow_forward, color: Colors.grey.shade600, size: 16),
                          Column(
                            children: [
                              Text(
                                "${serverResult?.stats?['optimized_strokes'] ?? 0}",
                                style: GoogleFonts.audiowide(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                              Text(
                                "Optimized",
                                style: GoogleFonts.audiowide(fontSize: 10, color: Colors.blue.shade600),
                              ),
                            ],
                          ),
                          Icon(Icons.arrow_forward, color: Colors.grey.shade600, size: 16),
                          Column(
                            children: [
                              Text(
                                "${serverResult?.totalPoints ?? 0}",
                                style: GoogleFonts.audiowide(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigo.shade700,
                                ),
                              ),
                              Text(
                                "Points",
                                style: GoogleFonts.audiowide(fontSize: 10, color: Colors.indigo.shade600),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
              ],

              // Status Message
              if (statusMessage != null) ...[
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 16),
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: statusMessage!.contains("SUCCESS") ||
                        statusMessage!.contains("successfully") ||
                        statusMessage!.contains("connected") ||
                        statusMessage!.contains("Ready to process")
                        ? Colors.green.shade50
                        : statusMessage!.contains("Error") ||
                        statusMessage!.contains("failed") ||
                        statusMessage!.contains("disconnected") ||
                        statusMessage!.contains("not connected")
                        ? Colors.red.shade50
                        : statusMessage!.contains("Processing") ||
                        statusMessage!.contains("Sending")
                        ? Colors.orange.shade50
                        : Colors.blue.shade50,
                    border: Border.all(
                      color: statusMessage!.contains("SUCCESS") ||
                          statusMessage!.contains("successfully") ||
                          statusMessage!.contains("connected") ||
                          statusMessage!.contains("Ready to process")
                          ? Colors.green.shade300
                          : statusMessage!.contains("Error") ||
                          statusMessage!.contains("failed") ||
                          statusMessage!.contains("disconnected") ||
                          statusMessage!.contains("not connected")
                          ? Colors.red.shade300
                          : statusMessage!.contains("Processing") ||
                          statusMessage!.contains("Sending")
                          ? Colors.orange.shade300
                          : Colors.blue.shade300,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        statusMessage!.contains("SUCCESS") ||
                            statusMessage!.contains("successfully") ||
                            statusMessage!.contains("connected") ||
                            statusMessage!.contains("Ready to process")
                            ? Icons.check_circle
                            : statusMessage!.contains("Error") ||
                            statusMessage!.contains("failed") ||
                            statusMessage!.contains("disconnected") ||
                            statusMessage!.contains("not connected")
                            ? Icons.error
                            : statusMessage!.contains("Processing") ||
                            statusMessage!.contains("Sending")
                            ? Icons.sync
                            : Icons.info,
                        color: statusMessage!.contains("SUCCESS") ||
                            statusMessage!.contains("successfully") ||
                            statusMessage!.contains("connected") ||
                            statusMessage!.contains("Ready to process")
                            ? Colors.green.shade700
                            : statusMessage!.contains("Error") ||
                            statusMessage!.contains("failed") ||
                            statusMessage!.contains("disconnected") ||
                            statusMessage!.contains("not connected")
                            ? Colors.red.shade700
                            : statusMessage!.contains("Processing") ||
                            statusMessage!.contains("Sending")
                            ? Colors.orange.shade700
                            : Colors.blue.shade700,
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          statusMessage!,
                          style: GoogleFonts.audiowide(
                            fontSize: 11,
                            color: statusMessage!.contains("SUCCESS") ||
                                statusMessage!.contains("successfully") ||
                                statusMessage!.contains("connected") ||
                                statusMessage!.contains("Ready to process")
                                ? Colors.green.shade700
                                : statusMessage!.contains("Error") ||
                                statusMessage!.contains("failed") ||
                                statusMessage!.contains("disconnected") ||
                                statusMessage!.contains("not connected")
                                ? Colors.red.shade700
                                : statusMessage!.contains("Processing") ||
                                statusMessage!.contains("Sending")
                                ? Colors.orange.shade700
                                : Colors.blue.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
              ],

            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNav(currentIndex: 2),
    );
  }

  Widget _buildTool(IconData icon, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade100 : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.blue.shade300 : Colors.grey.shade300,
          ),
        ),
        child: Icon(
          icon,
          color: isSelected ? Colors.blue.shade700 : Colors.grey.shade600,
          size: 20,
        ),
      ),
    );
  }

  void _showColorPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        final colors = [
          Colors.black, Colors.red, Colors.blue, Colors.green,
          Colors.yellow, Colors.orange, Colors.purple, Colors.pink, Colors.brown
        ];

        return Container(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Choose Color",
                style: GoogleFonts.audiowide(
                    fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: colors.map((color) {
                  return GestureDetector(
                    onTap: () {
                      setState(() => currentColor = color);
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey, width: 2),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}