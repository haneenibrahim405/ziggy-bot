import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:convert';

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
  final Color progressColor = Colors.white;

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
        responseMessage = "❌ Error picking image: ${e.toString()}";
      });
    }
  }

  Future<void> _uploadImage() async {
    if (_image == null) {
      setState(() {
        responseMessage = "❌ Please choose an image first";
      });
      return;
    }

    setState(() {
      isLoading = true;
      responseMessage = null;
    });

    try {
      var request = http.MultipartRequest(
        "POST",
        Uri.parse("http://192.168.1.5:8000/upload/")
      );

      request.files.add(await http.MultipartFile.fromPath("image", _image!.path));

      var response = await request.send();
      final resString = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = jsonDecode(resString);
        setState(() {
          responseMessage = "✅ Uploaded! Found ${data["stroke_count"]} strokes.";
        });
      } else {
        final errorData = jsonDecode(resString);
        setState(() {
          responseMessage = "❌ Upload failed: ${errorData["error"] ?? "Unknown error"}";
        });
      }
    } on SocketException {
      setState(() {
        responseMessage = "❌ Connection error: Cannot connect to server. Make sure the server is running.";
      });
    } on HttpException {
      setState(() {
        responseMessage = "❌ HTTP error: Could not connect to the server.";
      });
    } on FormatException {
      setState(() {
        responseMessage = "❌ Format error: Invalid response from server.";
      });
    } catch (e) {
      setState(() {
        responseMessage = "❌ Unexpected error: ${e.toString()}";
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: BottomNav(currentIndex: 1),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset("assets/ziggy.png", height: 120),
              const SizedBox(height: 20),
              Container(
                height: 400,
                width: double.infinity,
                constraints: BoxConstraints(maxWidth: 350),
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
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: iconColor,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      "Tap 'Choose Image' to select",
                      style: TextStyle(
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
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    child: Text("Choose Image"),
                  ),

                  const SizedBox(width: 15),

                  ElevatedButton(
                    onPressed: isLoading ? null : _uploadImage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: uploadButtonColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                    ),
                    child: isLoading
                        ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                        : Text("Upload"),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              if (isLoading) ...[
                Column(
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(uploadButtonColor),
                    ),
                    SizedBox(height: 10),
                    Text(
                      "Processing image...",
                      style: TextStyle(
                        fontSize: 16,
                        color: uploadButtonColor,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
              ],

              if (responseMessage != null) ...[
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: responseMessage!.contains("✅") ? Colors.green[50] : Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: responseMessage!.contains("✅") ? Colors.green : Colors.red,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    responseMessage!,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: responseMessage!.contains("✅") ? Colors.green[800] : Colors.red[800],
                    ),
                    textAlign: TextAlign.center,
                  ),
                )
              ]
            ],
          ),
        ),
      ),
    );
  }
}