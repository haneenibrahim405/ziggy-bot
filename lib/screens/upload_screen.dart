import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../widgets/bottom_nav.dart';

class UploadScreen extends StatefulWidget {
  @override
  _UploadScreenState createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  File? _image;
  bool isLoading = false;
  String? responseMessage;

  final Color containerColor = Color(0xFFE0E0E0);
  final Color chooseButtonColor = Color(0xFF231A4E);
  final Color uploadButtonColor = Color(0xFF231A4E);
  final Color iconColor = Color(0xFF231A4E);

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked != null) {
        setState(() {
          _image = File(picked.path);
          responseMessage = null;
        });
      }
    } catch (e) {
      setState(() {
        responseMessage = "Error picking image: ${e.toString()}";
      });
    }
  }

  Future<void> _processImage() async {
    if (_image == null) {
      setState(() {
        responseMessage = "Please choose an image first";
      });
      return;
    }

    setState(() {
      isLoading = true;
      responseMessage = null;
    });

    // Simulate processing time
    await Future.delayed(Duration(seconds: 2));

    setState(() {
      responseMessage = "Image processed successfully! (Local processing only)";
      isLoading = false;
    });
  }

  void _clearImage() {
    setState(() {
      _image = null;
      responseMessage = null;
      isLoading = false;
    });
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

              // Title
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
                child: _image == null
                    ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cloud_upload, size: 60, color: iconColor),
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
                      child: Image.file(_image!, fit: BoxFit.contain, width: double.infinity, height: double.infinity),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: isLoading ? null : _pickImage,
                    icon: Icon(Icons.image, size: 18),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: chooseButtonColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    label: Text(
                      "Choose Image",
                      style: GoogleFonts.audiowide(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  ElevatedButton.icon(
                    onPressed: (isLoading || _image == null) ? null : _processImage,
                    icon: isLoading
                        ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                        : Icon(Icons.auto_fix_high, size: 18),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: uploadButtonColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                    ),
                    label: Text(
                      isLoading ? "Processing..." : "Process",
                      style: GoogleFonts.audiowide(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

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
                      style: GoogleFonts.audiowide(
                        fontSize: 16,
                        color: uploadButtonColor,
                      ),
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
                    color: responseMessage!.contains("successfully")
                        ? Colors.green.shade50
                        : responseMessage!.contains("Error")
                        ? Colors.red.shade50
                        : Colors.blue.shade50,
                    border: Border.all(
                      color: responseMessage!.contains("successfully")
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
                        responseMessage!.contains("successfully")
                            ? Icons.check_circle
                            : responseMessage!.contains("Error")
                            ? Icons.error
                            : Icons.info,
                        color: responseMessage!.contains("successfully")
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
                            color: responseMessage!.contains("successfully")
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
              ],

              // Additional info
              const SizedBox(height: 20),
              Container(
                padding: EdgeInsets.all(16),
                margin: EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey.shade600, size: 24),
                    SizedBox(height: 8),
                    Text(
                      "Local Processing Only",
                      style: GoogleFonts.audiowide(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "This version processes images locally without external services.",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.audiowide(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}