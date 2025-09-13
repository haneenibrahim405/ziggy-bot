import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import '../service/image_processor.dart';
import '../widgets/bottom_nav.dart';
import 'package:http/http.dart' as http;
class UploadScreen extends StatefulWidget {
  @override
  _UploadScreenState createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  File? _image;
  String? _processedImageBase64;
  bool isLoading = false;
  String? responseMessage;
  img.Image? selectedImage;
  List<List<Point>> _extractedStrokes = [];
  Map<String, dynamic> _processingStats = {};

  final Color containerColor = Color(0xFFE0E0E0);
  final Color chooseButtonColor = Color(0xFF231A4E);
  final Color uploadButtonColor = Color(0xFF231A4E);
  final Color iconColor = Color(0xFF231A4E);

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked != null) {
        File imageFile = File(picked.path);

        await _convertFileToImage(imageFile);

        setState(() {
          _image = imageFile;
          _processedImageBase64 = null;
          _extractedStrokes = [];
          _processingStats = {};
          responseMessage = null;
        });
      }
    } catch (e) {
      setState(() {
        responseMessage = "Error picking image: ${e.toString()}";
      });
    }
  }

  Future<void> _convertFileToImage(File imageFile) async {
    try {
      Uint8List imageBytes = await imageFile.readAsBytes();
      img.Image? image = img.decodeImage(imageBytes);

      if (image != null) {
        selectedImage = image; // تحديث selectedImage
        print('Image converted successfully');
      } else {
        print('Failed to convert image');
        selectedImage = null;
      }
    } catch (e) {
      print('Error converting image: $e');
      selectedImage = null;
    }
  }

  Future<void> _processImage() async {
    if (_image == null || selectedImage == null) {
      setState(() {
        responseMessage = "Please choose an image first";
      });
      return;
    }

    setState(() {
      isLoading = true;
      responseMessage = "Processing image...";
    });

    try {
      ImageProcessingResult result = await ImageProcessor.processImageDirect(selectedImage);

      if (result.success) {
        setState(() {
          _extractedStrokes = result.strokes;
          _processedImageBase64 = result.processedImageBase64;
          _processingStats = result.stats;
          responseMessage = "Image processed successfully! Found ${result.strokes.length} strokes.";
          isLoading = false;
        });
      } else {
        setState(() {
          responseMessage = "Error processing image: ${result.error}";
          isLoading = false;
        });
      }

    } catch (e) {
      setState(() {
        responseMessage = "Error processing image: ${e.toString()}";
        isLoading = false;
      });
    }
  }

  void _clearImage() {
    setState(() {
      _image = null;
      selectedImage = null;
      _processedImageBase64 = null;
      _extractedStrokes = [];
      _processingStats = {};
      responseMessage = null;
      isLoading = false;
    });
  }

  Future<void> _sendToESP() async {
    List<Map<String, dynamic>> espData = ImageProcessor.convertToESPFormat(_extractedStrokes);

    // تحويل لـ JSON
    String jsonData = jsonEncode(espData);

    try {
      final response = await http.post(
        Uri.parse('http://192.168.1.100/draw'), // IP address بتاع الـ ESP
        headers: {'Content-Type': 'application/json'},
        body: jsonData,
      );

      if (response.statusCode == 200) {
        setState(() {
          responseMessage = "Drawing sent to ESP successfully!";
        });
      } else {
        setState(() {
          responseMessage = "Error sending to ESP: ${response.statusCode}";
        });
      }
    } catch (e) {
      setState(() {
        responseMessage = "Connection error: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: BottomNav(currentIndex: 0),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset("assets/ziggy.png", height: 120),
              const SizedBox(height: 20),

              Text(
                "IMAGE PROCESSOR",
                style: GoogleFonts.audiowide(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: uploadButtonColor,
                ),
              ),
              const SizedBox(height: 20),

              // Image display container
              Container(
                height: 300,
                width: double.infinity,
                constraints: BoxConstraints(maxWidth: 300),
                decoration: BoxDecoration(
                  color: containerColor,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: _processedImageBase64 != null
                    ? Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Image.memory(
                        base64Decode(_processedImageBase64!),
                        fit: BoxFit.contain,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    ),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          "Processed",
                          style: GoogleFonts.audiowide(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: _clearImage,
                        child: Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.8),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.close, color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ],
                )
                    : _image == null
                    ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cloud_upload, size: 60, color: Colors.white),
                    SizedBox(height: 10),
                    Text(
                      "Upload Image",
                      style: GoogleFonts.audiowide(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: iconColor,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      "Tap 'Choose Image' to select",
                      style: GoogleFonts.audiowide(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                )
                    : Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Image.file(
                        _image!,
                        fit: BoxFit.contain,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    ),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          "Original",
                          style: GoogleFonts.audiowide(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: _clearImage,
                        child: Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.8),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.close, color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Action buttons
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: isLoading ? null : _pickImage,
                    icon: Icon(Icons.image, size: 18, color: Colors.white),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: chooseButtonColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                    ),
                    label: Text(
                      "Choose Image",
                      style: GoogleFonts.audiowide(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),

                  ElevatedButton.icon(
                    onPressed: (isLoading || _image == null || selectedImage == null) ? null : _processImage,
                    icon: isLoading
                        ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                        : Icon(Icons.auto_fix_high, size: 18, color: Colors.white),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: uploadButtonColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                    ),
                    label: Text(
                      isLoading ? "Processing..." : "Process",
                      style: GoogleFonts.audiowide(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),

                  if (_extractedStrokes.isNotEmpty)
                    ElevatedButton.icon(
                      onPressed: _sendToESP,
                      icon: Icon(Icons.send, size: 18, color: Colors.white),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                      ),
                      label: Text(
                        "Send to robot",
                        style: GoogleFonts.audiowide(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 20),

              // Processing stats
              if (_processingStats.isNotEmpty) ...[
                Container(
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
                          Icon(Icons.analytics, color: Colors.blue.shade700, size: 20),
                          SizedBox(width: 8),
                          Text(
                            "Processing Results",
                            style: GoogleFonts.audiowide(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700),
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
                                "${_processingStats['optimizedStrokes']}",
                                style: GoogleFonts.audiowide(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                              Text(
                                "Strokes",
                                style: GoogleFonts.audiowide(fontSize: 12, color: Colors.blue.shade600),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              Text(
                                "${_processingStats['totalLength']}px",
                                style: GoogleFonts.audiowide(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade700,
                                ),
                              ),
                              Text(
                                "Total Length",
                                style: GoogleFonts.audiowide(fontSize: 12, color: Colors.green.shade600),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),
              ],

              // Loading indicator
              if (isLoading) ...[
                Column(
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(uploadButtonColor),
                    ),
                    SizedBox(height: 10),
                    Text(
                      "Processing image...",
                      style: GoogleFonts.audiowide(fontSize: 16, color: uploadButtonColor),
                    ),
                    SizedBox(height: 5),
                    Text(
                      "This may take a few seconds",
                      style: GoogleFonts.audiowide(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                SizedBox(height: 20),
              ],

              // Status message
              if (responseMessage != null) ...[
                Container(
                  padding: EdgeInsets.all(16),
                  margin: EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: responseMessage!.contains("successfully") || responseMessage!.contains("ready")
                        ? Colors.green.shade50
                        : responseMessage!.contains("Error")
                        ? Colors.red.shade50
                        : Colors.blue.shade50,
                    border: Border.all(
                      color: responseMessage!.contains("successfully") || responseMessage!.contains("ready")
                          ? Colors.green.shade300
                          : responseMessage!.contains("Error")
                          ? Colors.red.shade300
                          : Colors.blue.shade300,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        responseMessage!.contains("successfully") || responseMessage!.contains("ready")
                            ? Icons.check_circle
                            : responseMessage!.contains("Error")
                            ? Icons.error
                            : Icons.info,
                        color: responseMessage!.contains("successfully") || responseMessage!.contains("ready")
                            ? Colors.green.shade700
                            : responseMessage!.contains("Error")
                            ? Colors.red.shade700
                            : Colors.blue.shade700,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          responseMessage!,
                          style: GoogleFonts.audiowide(
                            fontSize: 14,
                            color: responseMessage!.contains("successfully") || responseMessage!.contains("ready")
                                ? Colors.green.shade700
                                : responseMessage!.contains("Error")
                                ? Colors.red.shade700
                                : Colors.blue.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),
              ],

            ],
          ),
        ),
      ),
    );
  }
}