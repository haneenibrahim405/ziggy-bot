import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import '../widgets/bottom_nav.dart';
import '../service/server_service.dart';

class UploadScreen extends StatefulWidget {
  @override
  _UploadScreenState createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  File? _image;
  bool isLoading = false;
  String? responseMessage;
  bool _isESPConnected = false;
  bool _isServerConnected = false;
  bool _isSendingToRobot = false;

  // Results from operations
  ServerProcessingResult? _serverResult;
  RobotSendResult? _robotResult;

  // Scale control
  double _drawingScale = 1.0;

  // UI colors
  final Color containerColor = Color(0xFFE0E0E0);
  final Color chooseButtonColor = Color(0xFF231A4E);
  final Color uploadButtonColor = Color(0xFF231A4E);
  final Color robotButtonColor = Color(0xFF28a745);
  final Color iconColor = Color(0xFF231A4E);

  @override
  void initState() {
    super.initState();
    _checkConnections();
  }

  /// Check both server and ESP connections
  Future<void> _checkConnections() async {
    setState(() {
      responseMessage = "Checking connections...";
    });

    bool serverConnected = await ServerService.checkServerConnection();
    bool espConnected = await ServerService.checkESPConnection();

    setState(() {
      _isServerConnected = serverConnected;
      _isESPConnected = espConnected;
      responseMessage = _getConnectionStatus();
    });
  }

  String _getConnectionStatus() {
    if (_isServerConnected && _isESPConnected) {
      return "✅ Server & ESP32 connected - Ready to process!";
    } else if (_isServerConnected && !_isESPConnected) {
      return "⚠️ Server connected, ESP32 disconnected";
    } else if (!_isServerConnected && _isESPConnected) {
      return "⚠️ ESP32 connected, Server disconnected";
    } else {
      return "❌ Both Server & ESP32 disconnected";
    }
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);

      if (picked != null) {
        setState(() {
          _image = File(picked.path);
          _serverResult = null;
          _robotResult = null;
          responseMessage = "Image selected successfully";
          _drawingScale = 1.0;
        });
      }
    } catch (e) {
      setState(() {
        responseMessage = "Error picking image: ${e.toString()}";
      });
    }
  }

  /// NEW: Send image directly to robot with GRBL commands
  Future<void> _sendDirectlyToRobot() async {
    if (_image == null) {
      setState(() {
        responseMessage = "Please choose an image first";
      });
      return;
    }

    if (!_isServerConnected) {
      setState(() {
        responseMessage = "Server not connected! Check connection first.";
      });
      return;
    }

    if (_isSendingToRobot) {
      setState(() {
        responseMessage = "Already processing! Please wait...";
      });
      return;
    }

    setState(() {
      _isSendingToRobot = true;
      responseMessage = "🤖 Processing and sending GRBL commands to robot with ${_drawingScale}x scale...";
    });

    try {
      RobotSendResult result = await ServerService.sendImageToRobot(
        _image!,
        scale: _drawingScale,
      );

      setState(() {
        _isSendingToRobot = false;
        _robotResult = result;

        if (result.success) {
          responseMessage = "🎉 SUCCESS! Robot received ${result.totalCommands} GRBL commands with ${result.appliedScale}x scale. Drawing should start now!";
        } else {
          responseMessage = "❌ Failed to send to robot: ${result.error}";
        }
      });

    } catch (e) {
      setState(() {
        _isSendingToRobot = false;
        responseMessage = "💥 Robot processing error: ${e.toString()}";
      });
    }
  }

  /// Process image using server (legacy method)
  Future<void> _processImageOnServer() async {
    if (_image == null) {
      setState(() {
        responseMessage = "Please choose an image first";
      });
      return;
    }

    if (!_isServerConnected) {
      setState(() {
        responseMessage = "Server not connected! Check connection first.";
      });
      return;
    }

    setState(() {
      isLoading = true;
      responseMessage = "🔄 Processing image on server...";
    });

    try {
      ServerProcessingResult result = await ServerService.processImageOnServer(_image!);

      setState(() {
        isLoading = false;
        _serverResult = result;

        if (result.success) {
          responseMessage = "✅ ${result.message} - Found ${result.totalStrokes ?? 0} strokes with ${result.totalPoints ?? 0} points";
        } else {
          responseMessage = "❌ ${result.error}";
        }
      });

    } catch (e) {
      setState(() {
        isLoading = false;
        responseMessage = "💥 Processing error: ${e.toString()}";
      });
    }
  }

  void _clearImage() {
    setState(() {
      _image = null;
      _serverResult = null;
      _robotResult = null;
      responseMessage = null;
      isLoading = false;
      _isSendingToRobot = false;
      _drawingScale = 1.0;
    });
  }

  String _getEstimatedDrawingSize() {
    int totalPoints = 0;

    if (_robotResult?.stats != null) {
      totalPoints = _robotResult!.stats!['total_commands'] ?? 0;
    } else if (_serverResult != null) {
      totalPoints = _serverResult!.totalPoints ?? 0;
    }

    if (totalPoints == 0) return "N/A";

    double estimatedSizeCm = (totalPoints * 0.3) * _drawingScale; // Estimate: each command = 0.3 cm

    if (estimatedSizeCm < 100) {
      return "${estimatedSizeCm.toStringAsFixed(1)} cm";
    } else {
      return "${(estimatedSizeCm / 100).toStringAsFixed(2)} m";
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
                "SPIDEY DRAW ROBOT",
                style: GoogleFonts.audiowide(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: uploadButtonColor,
                ),
              ),
              const SizedBox(height: 10),

              // Connection Status Indicators
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Server Status
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _isServerConnected ? Colors.green.shade50 : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _isServerConnected ? Colors.green : Colors.red,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isServerConnected ? Icons.cloud_done : Icons.cloud_off,
                          color: _isServerConnected ? Colors.green : Colors.red,
                          size: 16,
                        ),
                        SizedBox(width: 6),
                        Text(
                          "Server",
                          style: GoogleFonts.audiowide(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _isServerConnected ? Colors.green.shade700 : Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ESP32 Status
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _isESPConnected ? Colors.green.shade50 : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _isESPConnected ? Colors.green : Colors.red,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isESPConnected ? Icons.wifi : Icons.wifi_off,
                          color: _isESPConnected ? Colors.green : Colors.red,
                          size: 16,
                        ),
                        SizedBox(width: 6),
                        Text(
                          "ESP32",
                          style: GoogleFonts.audiowide(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _isESPConnected ? Colors.green.shade700 : Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Refresh Button
                  GestureDetector(
                    onTap: _checkConnections,
                    child: Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.blue.shade300),
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
                child: _robotResult?.processedImageBase64 != null
                    ? Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Image.memory(
                        base64Decode(_robotResult!.processedImageBase64!),
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
                          "Robot Processed",
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
                    : _serverResult?.processedImageBase64 != null
                    ? Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Image.memory(
                        base64Decode(_serverResult!.processedImageBase64!),
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
                          "Server Processed",
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
                    Icon(Icons.smart_toy, size: 60, color: Colors.white),
                    SizedBox(height: 10),
                    Text(
                      "Robot Drawing",
                      style: GoogleFonts.audiowide(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: iconColor,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      "Select image for robot processing",
                      style: GoogleFonts.audiowide(
                        fontSize: 12,
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
                          color: Colors.orange.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          "Ready for Robot",
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

              // Scale Control Section (always show when image is selected)
              if (_image != null) ...[
                Container(
                  padding: EdgeInsets.all(16),
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
                          Icon(Icons.zoom_in, color: Colors.purple.shade700, size: 20),
                          SizedBox(width: 8),
                          Text(
                            "Drawing Scale Control",
                            style: GoogleFonts.audiowide(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.purple.shade700,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Row(
                        children: [
                          Text(
                            "0.5x",
                            style: GoogleFonts.audiowide(
                              fontSize: 12,
                              color: Colors.purple.shade600,
                            ),
                          ),
                          Expanded(
                            child: Slider(
                              value: _drawingScale,
                              min: 0.5,
                              max: 3.0,
                              divisions: 25,
                              activeColor: Colors.purple.shade600,
                              inactiveColor: Colors.purple.shade200,
                              onChanged: (_isSendingToRobot || isLoading) ? null : (value) {
                                setState(() {
                                  _drawingScale = value;
                                });
                              },
                            ),
                          ),
                          Text(
                            "3.0x",
                            style: GoogleFonts.audiowide(
                              fontSize: 12,
                              color: Colors.purple.shade600,
                            ),
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
                                "${_drawingScale.toStringAsFixed(1)}x",
                                style: GoogleFonts.audiowide(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple.shade700,
                                ),
                              ),
                              Text(
                                "Scale",
                                style: GoogleFonts.audiowide(
                                    fontSize: 12,
                                    color: Colors.purple.shade600
                                ),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              Text(
                                _getEstimatedDrawingSize(),
                                style: GoogleFonts.audiowide(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                              Text(
                                "Est. Size",
                                style: GoogleFonts.audiowide(
                                    fontSize: 12,
                                    color: Colors.orange.shade600
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildScalePresetButton("0.5x", 0.5),
                          _buildScalePresetButton("1x", 1.0),
                          _buildScalePresetButton("1.5x", 1.5),
                          _buildScalePresetButton("2x", 2.0),
                          _buildScalePresetButton("3x", 3.0),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),
              ],

              // Action buttons
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  // Choose Image Button
                  ElevatedButton.icon(
                    onPressed: (isLoading || _isSendingToRobot) ? null : _pickImage,
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

                  // NEW: Send Directly to Robot Button (PRIMARY ACTION)
                  if (_image != null) ...[
                    ElevatedButton.icon(
                      onPressed: (_isServerConnected && !_isSendingToRobot && !isLoading) ? _sendDirectlyToRobot : null,
                      icon: _isSendingToRobot
                          ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                          : Icon(Icons.smart_toy, size: 18, color: Colors.white),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: (_isServerConnected && !_isSendingToRobot && !isLoading) ? robotButtonColor : Colors.grey,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        padding: EdgeInsets.symmetric(horizontal: 25, vertical: 12),
                      ),
                      label: Text(
                        _isSendingToRobot
                            ? "Sending to Robot..."
                            : _isServerConnected
                            ? "Send to Robot (GRBL)"
                            : "Server not connected",
                        style: GoogleFonts.audiowide(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ],

                  // Process on Server Button (SECONDARY ACTION)
                  ElevatedButton.icon(
                    onPressed: (isLoading || _image == null || !_isServerConnected || _isSendingToRobot)
                        ? null : _processImageOnServer,
                    icon: isLoading
                        ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                        : Icon(Icons.cloud_upload, size: 18, color: Colors.white),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: (_isServerConnected && !isLoading && !_isSendingToRobot) ? Colors.blue.shade600 : Colors.grey,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    label: Text(
                      isLoading
                          ? "Processing..."
                          : _isServerConnected
                          ? "Process Only"
                          : "Server not connected",
                      style: GoogleFonts.audiowide(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Robot Processing Results (NEW)
              if (_robotResult?.success == true && _robotResult?.stats != null) ...[
                Container(
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
                          Icon(Icons.smart_toy, color: Colors.green.shade700, size: 24),
                          SizedBox(width: 8),
                          Text(
                            "Robot GRBL Results",
                            style: GoogleFonts.audiowide(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              Text(
                                "${_robotResult?.stats?['original_strokes'] ?? 0}",
                                style: GoogleFonts.audiowide(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                              Text(
                                "Original Strokes",
                                style: GoogleFonts.audiowide(fontSize: 11, color: Colors.orange.shade600),
                              ),
                            ],
                          ),
                          Icon(Icons.arrow_forward, color: Colors.grey.shade600, size: 20),
                          Column(
                            children: [
                              Text(
                                "${_robotResult?.totalCommands ?? 0}",
                                style: GoogleFonts.audiowide(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade700,
                                ),
                              ),
                              Text(
                                "GRBL Commands",
                                style: GoogleFonts.audiowide(fontSize: 11, color: Colors.green.shade600),
                              ),
                            ],
                          ),
                          Icon(Icons.arrow_forward, color: Colors.grey.shade600, size: 20),
                          Column(
                            children: [
                              Text(
                                "${_robotResult?.appliedScale?.toStringAsFixed(1) ?? '1.0'}x",
                                style: GoogleFonts.audiowide(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple.shade700,
                                ),
                              ),
                              Text(
                                "Applied Scale",
                                style: GoogleFonts.audiowide(fontSize: 11, color: Colors.purple.shade600),
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

              // Server Processing Results (legacy)
              if (_serverResult?.success == true && _serverResult?.stats != null) ...[
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
                            "Server Processing Results",
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
                                "${_serverResult?.stats?['original_strokes'] ?? 0}",
                                style: GoogleFonts.audiowide(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                              Text(
                                "Original",
                                style: GoogleFonts.audiowide(fontSize: 12, color: Colors.orange.shade600),
                              ),
                            ],
                          ),
                          Icon(Icons.arrow_forward, color: Colors.grey.shade600),
                          Column(
                            children: [
                              Text(
                                "${_serverResult?.stats?['optimized_strokes'] ?? 0}",
                                style: GoogleFonts.audiowide(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                              Text(
                                "Optimized",
                                style: GoogleFonts.audiowide(fontSize: 12, color: Colors.blue.shade600),
                              ),
                            ],
                          ),
                          Icon(Icons.arrow_forward, color: Colors.grey.shade600),
                          Column(
                            children: [
                              Text(
                                "${_serverResult?.totalPoints ?? 0}",
                                style: GoogleFonts.audiowide(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigo.shade700,
                                ),
                              ),
                              Text(
                                "Points",
                                style: GoogleFonts.audiowide(fontSize: 12, color: Colors.indigo.shade600),
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

              // Processing indicators
              if (isLoading) ...[
                Column(
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(uploadButtonColor),
                    ),
                    SizedBox(height: 10),
                    Text(
                      "Processing on server...",
                      style: GoogleFonts.audiowide(fontSize: 16, color: uploadButtonColor),
                    ),
                    SizedBox(height: 5),
                    Text(
                      "Using advanced stroke optimization",
                      style: GoogleFonts.audiowide(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                SizedBox(height: 20),
              ],

              // Sending to Robot indicator
              if (_isSendingToRobot) ...[
                Column(
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(robotButtonColor),
                    ),
                    SizedBox(height: 10),
                    Text(
                      "Sending to robot...",
                      style: GoogleFonts.audiowide(fontSize: 16, color: robotButtonColor),
                    ),
                    SizedBox(height: 5),
                    Text(
                      "Processing image and generating GRBL commands",
                      style: GoogleFonts.audiowide(fontSize: 12, color: Colors.grey),
                    ),
                    SizedBox(height: 5),
                    Text(
                      "Scale: ${_drawingScale.toStringAsFixed(1)}x",
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
                    color: responseMessage!.contains("SUCCESS") ||
                        responseMessage!.contains("successfully") ||
                        responseMessage!.contains("Connected") ||
                        responseMessage!.contains("Ready to process")
                        ? Colors.green.shade50
                        : responseMessage!.contains("Error") ||
                        responseMessage!.contains("failed") ||
                        responseMessage!.contains("disconnected") ||
                        responseMessage!.contains("not connected")
                        ? Colors.red.shade50
                        : responseMessage!.contains("Processing") ||
                        responseMessage!.contains("Uploading") ||
                        responseMessage!.contains("Sending")
                        ? Colors.orange.shade50
                        : Colors.blue.shade50,
                    border: Border.all(
                      color: responseMessage!.contains("SUCCESS") ||
                          responseMessage!.contains("successfully") ||
                          responseMessage!.contains("Connected") ||
                          responseMessage!.contains("Ready to process")
                          ? Colors.green.shade300
                          : responseMessage!.contains("Error") ||
                          responseMessage!.contains("failed") ||
                          responseMessage!.contains("disconnected") ||
                          responseMessage!.contains("not connected")
                          ? Colors.red.shade300
                          : responseMessage!.contains("Processing") ||
                          responseMessage!.contains("Uploading") ||
                          responseMessage!.contains("Sending")
                          ? Colors.orange.shade300
                          : Colors.blue.shade300,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        responseMessage!.contains("SUCCESS") ||
                            responseMessage!.contains("successfully") ||
                            responseMessage!.contains("Connected") ||
                            responseMessage!.contains("Ready to process")
                            ? Icons.check_circle
                            : responseMessage!.contains("Error") ||
                            responseMessage!.contains("failed") ||
                            responseMessage!.contains("disconnected") ||
                            responseMessage!.contains("not connected")
                            ? Icons.error
                            : responseMessage!.contains("Processing") ||
                            responseMessage!.contains("Uploading") ||
                            responseMessage!.contains("Sending")
                            ? Icons.sync
                            : Icons.info,
                        color: responseMessage!.contains("SUCCESS") ||
                            responseMessage!.contains("successfully") ||
                            responseMessage!.contains("Connected") ||
                            responseMessage!.contains("Ready to process")
                            ? Colors.green.shade700
                            : responseMessage!.contains("Error") ||
                            responseMessage!.contains("failed") ||
                            responseMessage!.contains("disconnected") ||
                            responseMessage!.contains("not connected")
                            ? Colors.red.shade700
                            : responseMessage!.contains("Processing") ||
                            responseMessage!.contains("Uploading") ||
                            responseMessage!.contains("Sending")
                            ? Colors.orange.shade700
                            : Colors.blue.shade700,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          responseMessage!,
                          style: GoogleFonts.audiowide(
                            fontSize: 14,
                            color: responseMessage!.contains("SUCCESS") ||
                                responseMessage!.contains("successfully") ||
                                responseMessage!.contains("Connected") ||
                                responseMessage!.contains("Ready to process")
                                ? Colors.green.shade700
                                : responseMessage!.contains("Error") ||
                                responseMessage!.contains("failed") ||
                                responseMessage!.contains("disconnected") ||
                                responseMessage!.contains("not connected")
                                ? Colors.red.shade700
                                : responseMessage!.contains("Processing") ||
                                responseMessage!.contains("Uploading") ||
                                responseMessage!.contains("Sending")
                                ? Colors.orange.shade700
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

  /// Helper method to build scale preset buttons
  Widget _buildScalePresetButton(String label, double scale) {
    bool isSelected = (_drawingScale - scale).abs() < 0.05;

    return GestureDetector(
      onTap: (_isSendingToRobot || isLoading) ? null : () {
        setState(() {
          _drawingScale = scale;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.purple.shade600 : Colors.purple.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.purple.shade600 : Colors.purple.shade300,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.audiowide(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : Colors.purple.shade700,
          ),
        ),
      ),
    );
  }
}