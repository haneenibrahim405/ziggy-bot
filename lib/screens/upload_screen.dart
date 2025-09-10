import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../widgets/bottom_nav.dart';
import '../services/upload_service.dart';

class UploadScreen extends StatefulWidget {
  @override
  _UploadScreenState createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  File? _image;
  bool isLoading = false;
  String? responseMessage;

  final UploadService _uploadService = UploadService();

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

  Future<void> _uploadImage() async {
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

    final result = await _uploadService.uploadImage(_image!);

    setState(() {
      responseMessage = result;
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

              // Original image
              if (_image != null) ...[
                Text(
                  "Original Image",
                    style: GoogleFonts.audiowide(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: uploadButtonColor,
                  ),
                ),
                const SizedBox(height: 10),
              ],
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
                      "Upload PNG Image",
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
                    : Image.file(_image!, fit: BoxFit.contain),
              ),

              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: isLoading ? null : _pickImage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: chooseButtonColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding:
                      EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    child: Text(
                        "Choose Image",
                        style: GoogleFonts.audiowide(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  ElevatedButton(
                    onPressed:
                    (isLoading || _image == null) ? null : _uploadImage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: uploadButtonColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding:
                      EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                    ),
                    child: isLoading
                        ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                        : Text(
                        "Upload",
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

              if (isLoading) ...[
                Column(
                  children: [
                    CircularProgressIndicator(
                      valueColor:
                      AlwaysStoppedAnimation<Color>(uploadButtonColor),
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
              if (responseMessage != null) ...[
                Text(
                  "Processed Image",
                  style: GoogleFonts.audiowide(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: uploadButtonColor,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  height: 300,
                  width: double.infinity,
                  constraints: BoxConstraints(maxWidth: 300),
                  decoration: BoxDecoration(
                    color: containerColor,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Builder(
                    builder: (_) {
                      final processedBytes =
                      _uploadService.lastResult?.getProcessedImageBytes();

                      if (processedBytes != null) {
                        return Image.memory(processedBytes, fit: BoxFit.contain);
                      } else {
                        return Center(
                          child: Text(
                            responseMessage ?? "No processed image",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}
