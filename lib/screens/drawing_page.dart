import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import '../models/sketch.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/paint_canvas.dart';

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
  double currentEraserSize = 20.0;
  int currentBrushMode = 1;
  bool isEraserMode = false;
  Sketch? selectedSketch;

  Future<File?> saveDrawing() async {
    try {
      RenderRepaintBoundary boundary = repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;

      // زيادة جودة الصورة
      ui.Image image = await boundary.toImage(pixelRatio: 5.0);

      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        throw Exception("Failed to convert image to byte data");
      }

      Uint8List pngBytes = byteData.buffer.asUint8List();

      final pixels = byteData.buffer.asUint32List();
      bool isWhite = pixels.every((color) {
        return color == 0xFFFFFFFF;
      });

      if (isWhite) {
        print("Canvas is empty (white image).");
        return null;
      }

      if (pngBytes.isEmpty) {
        throw Exception("Image data is empty");
      }

      final directory = await getApplicationDocumentsDirectory();
      String fileName = 'drawing_${DateTime.now().millisecondsSinceEpoch}.png';
      File imgFile = File('${directory.path}/$fileName');

      await imgFile.writeAsBytes(pngBytes);

      if (!await imgFile.exists()) {
        throw Exception("Failed to create image file");
      }

      final length = await imgFile.length();
      if (length == 0) {
        throw Exception("Created file is empty");
      }

      print("Image saved successfully: ${imgFile.path}, size: ${length} bytes");
      return imgFile;
    } catch (e) {
      print("Error saving drawing: $e");
      throw Exception("Error saving drawing: $e");
    }
  }

  void clearCanvas() {
    setState(() {
      sketches.clear();
      selectedSketch = null;
    });
  }

  void removeSelectedSketch() {
    if (selectedSketch != null) {
      setState(() {
        sketches.remove(selectedSketch);
        selectedSketch = null;
      });
    }
  }

  void undoLast() {
    if (sketches.isNotEmpty) {
      setState(() {
        sketches.removeLast();
        selectedSketch = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade50, Colors.grey.shade100],
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
            ),

            // Drawing tools section
            Container(
              height: 80,
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Drawing tools
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildToolButton(
                            icon: Icons.brush,
                            tooltip: "Pen",
                            isSelected: !isEraserMode && currentBrushMode == 1,
                            onTap: () => setState(() {
                              isEraserMode = false;
                              currentBrushMode = 1;
                              selectedSketch = null;
                            }),
                          ),
                          SizedBox(width: 12),
                          _buildToolButton(
                            icon: Icons.auto_delete,
                            tooltip: "Eraser",
                            isSelected: isEraserMode,
                            onTap: () => setState(() {
                              isEraserMode = true;
                              selectedSketch = null;
                            }),
                          ),
                          SizedBox(width: 12),
                          _buildToolButton(
                            icon: Icons.horizontal_rule,
                            tooltip: "Line",
                            isSelected: !isEraserMode && currentBrushMode == 2,
                            onTap: () => setState(() {
                              isEraserMode = false;
                              currentBrushMode = 2;
                              selectedSketch = null;
                            }),
                          ),
                          SizedBox(width: 12),
                          _buildToolButton(
                            icon: Icons.circle_outlined,
                            tooltip: "Circle",
                            isSelected: !isEraserMode && currentBrushMode == 3,
                            onTap: () => setState(() {
                              isEraserMode = false;
                              currentBrushMode = 3;
                              selectedSketch = null;
                            }),
                          ),
                          SizedBox(width: 12),
                          _buildToolButton(
                            icon: Icons.crop_square,
                            tooltip: "Rectangle",
                            isSelected: !isEraserMode && currentBrushMode == 4,
                            onTap: () => setState(() {
                              isEraserMode = false;
                              currentBrushMode = 4;
                              selectedSketch = null;
                            }),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Color and utility tools
                  Row(
                    children: [
                      // Color picker
                      PopupMenuButton<Color>(
                        icon: Container(
                          padding: EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey.shade400),
                            color: currentColor,
                          ),
                          child: Icon(
                            Icons.color_lens,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        itemBuilder: (context) => [
                          PopupMenuItem(value: Colors.black, child: Container(color: Colors.black, height: 24)),
                          PopupMenuItem(value: Colors.red, child: Container(color: Colors.red, height: 24)),
                          PopupMenuItem(value: Colors.blue, child: Container(color: Colors.blue, height: 24)),
                          PopupMenuItem(value: Colors.green, child: Container(color: Colors.green, height: 24)),
                          PopupMenuItem(value: Colors.yellow, child: Container(color: Colors.yellow, height: 24)),
                          PopupMenuItem(value: Colors.orange, child: Container(color: Colors.orange, height: 24)),
                          PopupMenuItem(value: Colors.purple, child: Container(color: Colors.purple, height: 24)),
                        ],
                        onSelected: (color) => setState(() => currentColor = color),
                      ),
                      SizedBox(width: 12),

                      // Delete selected
                      if (selectedSketch != null)
                        _buildUtilityButton(
                          icon: Icons.delete_outline,
                          tooltip: "Delete Selected",
                          onPressed: removeSelectedSketch,
                          color: Colors.red,
                        ),

                      // Undo
                      _buildUtilityButton(
                        icon: Icons.undo,
                        tooltip: "Undo",
                        onPressed: undoLast,
                      ),

                      // Clear all
                      _buildUtilityButton(
                        icon: Icons.delete_sweep,
                        tooltip: "Clear All",
                        onPressed: clearCanvas,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Drawing canvas
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    margin: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade300, width: 1),
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
                              estrokeSize: currentEraserSize,
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
                        onTapUp: (details) {
                          setState(() {
                            selectedSketch = null;
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
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Action buttons
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, -2),
                  )
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Save button
                  ElevatedButton.icon(
                    icon: Icon(Icons.save, size: 20),
                    label: Text("Save", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    onPressed: () async {
                      if (sketches.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Canvas is empty! Please draw something before saving."),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }

                      try {
                        File? img = await saveDrawing();
                        if (img != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Drawing saved successfully!"),
                                backgroundColor: Colors.green,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                duration: Duration(seconds: 2),
                              )
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Canvas is empty, nothing to save."),
                                backgroundColor: Colors.orange,
                              )
                          );
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Save error: $e"),
                              backgroundColor: Colors.red,
                            )
                        );
                      }
                    },
                  ),

                  // Clear button (replacing upload)
                  ElevatedButton.icon(
                    icon: Icon(Icons.clear_all, size: 20),
                    label: Text("Clear All", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    onPressed: () {
                      if (sketches.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Canvas is already empty!"),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }

                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: Text("Clear Canvas"),
                            content: Text("Are you sure you want to clear all drawings?"),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: Text("Cancel"),
                              ),
                              TextButton(
                                onPressed: () {
                                  clearCanvas();
                                  Navigator.of(context).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text("Canvas cleared successfully!"),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                },
                                child: Text("Clear", style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNav(currentIndex: 2),
    );
  }

  Widget _buildToolButton({
    required IconData icon,
    required String tooltip,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue.shade100 : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: isSelected ? Colors.blue.shade600 : Colors.grey.shade300,
                width: 1.5
            ),
          ),
          child: Icon(
            icon,
            color: isSelected ? Colors.blue.shade800 : Colors.grey.shade600,
            size: 22,
          ),
        ),
      ),
    );
  }

  Widget _buildUtilityButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    Color color = Colors.grey,
  }) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon, color: color),
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: Colors.grey.shade100,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}