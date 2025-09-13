import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import '../models/sketch.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/paint_canvas.dart';
import '../service/image_processor.dart';

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

  // Processing variables
  bool isProcessing = false;
  String? processedImageBase64;
  String? statusMessage;

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

  Future<void> processDrawing() async {
    if (sketches.isEmpty) {
      setState(() {
        statusMessage = "Canvas is empty! Please draw something first.";
      });
      return;
    }

    setState(() {
      isProcessing = true;
      statusMessage = "Processing drawing...";
      processedImageBase64 = null;
    });

    try {
      File? imageFile = await saveDrawing();
      if (imageFile == null) {
        throw Exception("Failed to save drawing");
      }

      Uint8List imageBytes = await imageFile.readAsBytes();
      img.Image? image = img.decodeImage(imageBytes);

      if (image == null) {
        throw Exception('Failed to decode image');
      }

      ImageProcessingResult result = await ImageProcessor.processImageDirect(image);

      if (result.success) {
        setState(() {
          processedImageBase64 = result.processedImageBase64;
          statusMessage = "Processing complete! Found ${result.strokes.length} strokes.";
          isProcessing = false;
        });
      } else {
        setState(() {
          statusMessage = "Error: ${result.error}";
          isProcessing = false;
        });
      }

    } catch (e) {
      setState(() {
        statusMessage = "Error: ${e.toString()}";
        isProcessing = false;
      });
    }
  }

  void clearCanvas() {
    setState(() {
      sketches.clear();
      processedImageBase64 = null;
      statusMessage = null;
    });
  }

  void undoLast() {
    if (sketches.isNotEmpty) {
      setState(() {
        sketches.removeLast();
      });
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
              // App bar
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
                child: Row(
                  children: [
                    Icon(Icons.draw, color: Colors.blue.shade700, size: 28),
                    SizedBox(width: 12),
                    Text(
                      "Drawing Canvas",
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
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
                height: MediaQuery.of(context).size.height - 200, // Fixed height
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Drawing Canvas
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
                      flex: 1,
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
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(12),
                                  topRight: Radius.circular(12),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.auto_fix_high, color: Colors.blue.shade700, size: 18),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      "Processed Image",
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue.shade700,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Image Area
                            Expanded(
                              child: Container(
                                width: double.infinity,
                                padding: EdgeInsets.all(12),
                                child: processedImageBase64 != null
                                    ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.memory(
                                    base64Decode(processedImageBase64!),
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
                                        Icons.image_not_supported_outlined,
                                        size: 32,
                                        color: Colors.grey.shade400,
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        "Processed image will appear here",
                                        style: GoogleFonts.poppins(
                                          color: Colors.grey.shade600,
                                          fontSize: 12,
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // Status Message
                            if (statusMessage != null)
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.all(8),
                                margin: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: statusMessage!.contains("Error")
                                      ? Colors.red.shade50
                                      : Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: statusMessage!.contains("Error")
                                        ? Colors.red.shade200
                                        : Colors.green.shade200,
                                  ),
                                ),
                                child: Text(
                                  statusMessage!,
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    color: statusMessage!.contains("Error")
                                        ? Colors.red.shade700
                                        : Colors.green.shade700,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Process Button
              Container(
                padding: EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: isProcessing ? null : processDrawing,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: isProcessing
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
                        SizedBox(width: 12),
                        Text("Processing..."),
                      ],
                    )
                        : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.auto_fix_high),
                        SizedBox(width: 8),
                        Text("Process Drawing"),
                      ],
                    ),
                  ),
                ),
              ),
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
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
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