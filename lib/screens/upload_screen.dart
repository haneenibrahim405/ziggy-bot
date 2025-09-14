import 'dart:math';

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

// Python Server Service
class PythonServerService {
  static const String serverUrl = 'http://192.168.1.100:8000'; // Replace with your Python server IP
  
  static Future<ServerProcessingResult> processImageOnServer(img.Image image) async {
    try {
      Uint8List imageBytes = Uint8List.fromList(img.encodePng(image));
      
      var request = http.MultipartRequest(
        'POST', 
        Uri.parse('$serverUrl/upload/')
      );
      
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          imageBytes,
          filename: 'upload.png',
        ),
      );
      
      print("📤 Sending image to Python server...");
      
      var response = await request.send().timeout(Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        String responseBody = await response.stream.bytesToString();
        Map<String, dynamic> jsonResponse = json.decode(responseBody);
        
        return ServerProcessingResult.fromJson(jsonResponse);
      } else {
        throw Exception('Server responded with status: ${response.statusCode}');
      }
      
    } catch (e) {
      print("❌ Error communicating with Python server: $e");
      throw Exception('Failed to process on server: $e');
    }
  }
  
  static List<Map<String, dynamic>> convertToESPCommands(
    List<List<dynamic>> optimizedStrokes, 
    {double scale = 1.0}
  ) {
    List<Map<String, dynamic>> commands = [];
    
    for (var stroke in optimizedStrokes) {
      if (stroke.length < 2) continue;
      
      for (int i = 0; i < stroke.length - 1; i++) {
        var point1 = stroke[i];
        var point2 = stroke[i + 1];
        
        double dx = (point2[0] - point1[0]) * scale;
        double dy = (point2[1] - point1[1]) * scale;
        
        double distance = sqrt((dx * dx + dy * dy));
        double angleRad = atan2(dy , dx);
        int angleDeg = (angleRad * 180 / 3.14159).round() % 360;
        if (angleDeg < 0) angleDeg += 360;
        
        int repeats = (distance / 1.0).ceil().clamp(1, 50);
        
        if (repeats > 0) {
          commands.add({
            'angle': angleDeg,
            'repeats': repeats,
            'originalDistance': distance,
            'estimatedTime': _estimateCommandTime(repeats),
          });
        }
      }
    }
    
    return _optimizeCommands(commands);
  }
  
  static List<Map<String, dynamic>> _optimizeCommands(List<Map<String, dynamic>> commands) {
    if (commands.isEmpty) return [];
    
    List<Map<String, dynamic>> optimized = [];
    Map<String, dynamic> current = Map.from(commands[0]);
    
    for (int i = 1; i < commands.length; i++) {
      var next = commands[i];
      
      if (current['angle'] == next['angle']) {
        int totalRepeats = (current['repeats'] + next['repeats']).clamp(1, 50);
        current['repeats'] = totalRepeats;
        current['estimatedTime'] = _estimateCommandTime(totalRepeats);
      } else {
        optimized.add(current);
        current = Map.from(next);
      }
    }
    
    optimized.add(current);
    return optimized;
  }
  
  static int _estimateCommandTime(int repeats) {
    const int baseTimePerRepeat = 150;
    const int setupTime = 50;
    return setupTime + (repeats * baseTimePerRepeat);
  }
}

class ServerProcessingResult {
  final List<List<dynamic>> optimizedStrokes;
  final List<Map<String, dynamic>> robotPath;
  final Map<String, dynamic> optimizationStats;
  final String? processedImageBase64;
  final bool success;
  final String? error;
  
  ServerProcessingResult({
    required this.optimizedStrokes,
    required this.robotPath,
    required this.optimizationStats,
    this.processedImageBase64,
    this.success = true,
    this.error,
  });
  
  factory ServerProcessingResult.fromJson(Map<String, dynamic> json) {
    try {
      return ServerProcessingResult(
        optimizedStrokes: List<List<dynamic>>.from(
          json['optimized_strokes']?.map((stroke) => List<dynamic>.from(stroke)) ?? []
        ),
        robotPath: List<Map<String, dynamic>>.from(
          json['robot_path']?.map((point) => Map<String, dynamic>.from(point)) ?? []
        ),
        optimizationStats: Map<String, dynamic>.from(json['optimization_stats'] ?? {}),
        processedImageBase64: json['processed_image'],
        success: true,
      );
    } catch (e) {
      return ServerProcessingResult(
        optimizedStrokes: [],
        robotPath: [],
        optimizationStats: {},
        success: false,
        error: 'Failed to parse server response: $e',
      );
    }
  }
  
  factory ServerProcessingResult.error(String message) {
    return ServerProcessingResult(
      optimizedStrokes: [],
      robotPath: [],
      optimizationStats: {},
      success: false,
      error: message,
    );
  }
}

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
  bool _isESPConnected = false;

  // Variables for preventing duplication
  bool _isSendingCommands = false;
  List<Map<String, dynamic>> _lastProcessedCommands = [];

  // Scale variable
  double _drawingScale = 1.0;

  // Python server integration variables
  bool _useServerProcessing = false;
  ServerProcessingResult? _serverResult;
  bool _isProcessingOnServer = false;

  final Color containerColor = Color(0xFFE0E0E0);
  final Color chooseButtonColor = Color(0xFF231A4E);
  final Color uploadButtonColor = Color(0xFF231A4E);
  final Color iconColor = Color(0xFF231A4E);

  @override
  void initState() {
    super.initState();
    _checkESPConnection();
  }

  Future<void> _checkESPConnection() async {
    try {
      print("🔍 Testing ESP32 connection...");
      final response = await http.get(
        Uri.parse('http://192.168.4.1/status'),
        headers: {'Connection': 'close'},
      ).timeout(Duration(seconds: 3));

      if (response.statusCode == 200) {
        setState(() {
          _isESPConnected = true;
          responseMessage = "ESP32 connected successfully!";
        });
        print("✅ ESP32 connection: SUCCESS");
      } else {
        setState(() {
          _isESPConnected = false;
          responseMessage = "ESP32 responded with status ${response.statusCode}";
        });
        print("⚠️ ESP32 connection: Status ${response.statusCode}");
      }
    } catch (e) {
      setState(() {
        _isESPConnected = false;
        responseMessage = "Cannot connect to ESP32: $e";
      });
      print("❌ ESP32 connection: FAILED - $e");
    }
  }

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
          _lastProcessedCommands.clear();
          _drawingScale = 1.0;
          _serverResult = null;
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
        selectedImage = image;
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
      responseMessage = _useServerProcessing 
          ? "Processing image on Python server..." 
          : "Processing image locally...";
      _lastProcessedCommands.clear();
    });

    try {
      if (_useServerProcessing) {
        await _processImageOnServer();
      } else {
        await _processImageLocally();
      }
    } catch (e) {
      setState(() {
        responseMessage = "Error processing image: ${e.toString()}";
        isLoading = false;
      });
    }
  }

  Future<void> _processImageOnServer() async {
    setState(() {
      _isProcessingOnServer = true;
      responseMessage = "Sending image to Python server for advanced processing...";
    });

    try {
      _serverResult = await PythonServerService.processImageOnServer(selectedImage!);
      
      if (_serverResult!.success) {
        List<Map<String, dynamic>> serverCommands = PythonServerService.convertToESPCommands(
          _serverResult!.optimizedStrokes,
          scale: _drawingScale
        );
        
        setState(() {
          _extractedStrokes = _serverResult!.optimizedStrokes
              .map((stroke) => stroke.map((point) => Point(point[0].toDouble(), point[1].toDouble())).toList())
              .toList();
          _lastProcessedCommands = serverCommands;
          _processedImageBase64 = _serverResult!.processedImageBase64;
          _processingStats = _serverResult!.optimizationStats;
          responseMessage = "Server processing completed! Found ${_serverResult!.optimizedStrokes.length} optimized strokes.";
          isLoading = false;
          _isProcessingOnServer = false;
        });
      } else {
        throw Exception(_serverResult!.error ?? "Server processing failed");
      }
      
    } catch (e) {
      setState(() {
        responseMessage = "Server processing failed: $e. Falling back to local processing...";
        _isProcessingOnServer = false;
      });
      
      await _processImageLocally();
    }
  }

  Future<void> _processImageLocally() async {
    ImageProcessingResult result = await ImageProcessor.processImageDirect(selectedImage!);

    if (result.success) {
      setState(() {
        _extractedStrokes = result.strokes;
        _processedImageBase64 = result.processedImageBase64;
        _processingStats = result.stats;
        responseMessage = "Local processing completed! Found ${result.strokes.length} strokes.";
        isLoading = false;
        _lastProcessedCommands.clear();
      });
    } else {
      setState(() {
        responseMessage = "Error in local processing: ${result.error}";
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
      _lastProcessedCommands.clear();
      _isSendingCommands = false;
      _drawingScale = 1.0;
      _serverResult = null;
      _useServerProcessing = false;
    });
  }

  List<Map<String, dynamic>> _extractCommandsOnce() {
    if (_useServerProcessing && _serverResult != null && _serverResult!.success) {
      if (_lastProcessedCommands.isNotEmpty) {
        print("📄 Using cached server commands: ${_lastProcessedCommands.length} with scale $_drawingScale");
        return _applyScaleToCommands(_lastProcessedCommands);
      }
      
      List<Map<String, dynamic>> serverCommands = PythonServerService.convertToESPCommands(
        _serverResult!.optimizedStrokes,
        scale: _drawingScale
      );
      
      _lastProcessedCommands = List.from(serverCommands);
      print("🆕 Extracted fresh server commands: ${serverCommands.length}");
      
      return _applyScaleToCommands(serverCommands);
    }
    
    if (_lastProcessedCommands.isNotEmpty) {
      print("📄 Using cached commands: ${_lastProcessedCommands.length} with scale $_drawingScale");
      return _applyScaleToCommands(_lastProcessedCommands);
    }

    List<Map<String, dynamic>> espData = ImageProcessor.convertToESPFormat(_extractedStrokes);
    List<Map<String, dynamic>> commands = [];

    for (var item in espData) {
      if (item.containsKey('commands') && item['commands'] is List) {
        List<dynamic> commandList = item['commands'];
        for (var cmd in commandList) {
          if (cmd is Map<String, dynamic>) {
            int steps = (cmd['steps'] ?? 0).round();
            if (steps > 0) {
              int angle = (cmd['angle'] ?? 90).round() % 360;
              int repeats = ((steps / 50).ceil()).clamp(1, 20);
              commands.add({
                'angle': angle,
                'repeats': repeats,
                'originalSteps': steps,
                'estimatedTime': _estimateCommandTime(repeats),
              });
            }
          }
        }
      }
    }

    _lastProcessedCommands = List.from(commands);
    print("🆕 Extracted fresh commands: ${commands.length}");

    return _applyScaleToCommands(commands);
  }

  List<Map<String, dynamic>> _applyScaleToCommands(List<Map<String, dynamic>> originalCommands) {
    if (_drawingScale == 1.0) {
      return originalCommands;
    }

    List<Map<String, dynamic>> scaledCommands = [];

    for (var cmd in originalCommands) {
      int originalSteps = cmd['originalSteps'] ?? cmd['repeats'] * 50;

      int scaledSteps = (originalSteps * _drawingScale).round();
      int scaledRepeats = ((scaledSteps / 50).ceil()).clamp(1, 50);

      scaledCommands.add({
        'angle': cmd['angle'],
        'repeats': scaledRepeats,
        'originalSteps': originalSteps,
        'scaledSteps': scaledSteps,
        'estimatedTime': _estimateCommandTime(scaledRepeats),
      });
    }

    print("🔧 Applied scale $_drawingScale: ${originalCommands.length} commands scaled");
    return scaledCommands;
  }

  String _getEstimatedDrawingSize() {
    if (_extractedStrokes.isEmpty) return "N/A";

    List<Map<String, dynamic>> commands = _extractCommandsOnce();
    double totalSteps = 0;

    for (var cmd in commands) {
      totalSteps += (cmd['scaledSteps'] ?? cmd['repeats'] * 50);
    }

    double estimatedSizeCm = (totalSteps / 50) * 3 * _drawingScale;

    if (estimatedSizeCm < 100) {
      return "${estimatedSizeCm.toStringAsFixed(1)} cm";
    } else {
      return "${(estimatedSizeCm / 100).toStringAsFixed(2)} m";
    }
  }

  int _estimateCommandTime(int repeats) {
    const int baseTimePerRepeat = 150;
    const int setupTime = 50;
    return setupTime + (repeats * baseTimePerRepeat);
  }

  int _calculateSmartDelay(int repeats) {
    if (repeats <= 2) {
      return 300;
    } else if (repeats <= 5) {
      return 500;
    } else if (repeats <= 10) {
      return 800;
    } else {
      return 1200;
    }
  }

  List<Map<String, dynamic>> _groupSimilarCommands(List<Map<String, dynamic>> commands) {
    if (commands.isEmpty) return [];

    List<Map<String, dynamic>> grouped = [];
    Map<String, dynamic> current = Map.from(commands[0]);

    for (int i = 1; i < commands.length; i++) {
      Map<String, dynamic> next = commands[i];

      if (current['angle'] == next['angle']) {
        int totalRepeats = (current['repeats'] + next['repeats']).clamp(1, 50);
        current['repeats'] = totalRepeats;

        if (current.containsKey('scaledSteps') && next.containsKey('scaledSteps')) {
          current['scaledSteps'] = current['scaledSteps'] + next['scaledSteps'];
        }
      } else {
        grouped.add(current);
        current = Map.from(next);
      }
    }

    grouped.add(current);
    return grouped;
  }

  Future<bool> _sendSingleCommandWithRetry(int angle, int repeats, int commandNumber) async {
    String url = 'http://192.168.4.1/move?angle=$angle&repeats=$repeats';

    const int maxRetries = 2;
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print("📡 Attempt $attempt/$maxRetries for command $commandNumber");

        final response = await http.get(
          Uri.parse(url),
          headers: {
            'User-Agent': 'Flutter-App',
            'Connection': 'close',
          },
        ).timeout(Duration(seconds: 5));

        if (response.statusCode == 200) {
          print("✅ Command $commandNumber sent successfully on attempt $attempt");
          return true;
        } else {
          print("❌ Command $commandNumber failed on attempt $attempt - Status: ${response.statusCode}");
        }
      } catch (e) {
        print("💥 Command $commandNumber error on attempt $attempt: $e");
      }

      if (attempt < maxRetries) {
        await Future.delayed(Duration(milliseconds: 300));
      }
    }

    return false;
  }

  Future<void> _checkIfESPFinished() async {
    try {
      print("🔍 Checking if ESP32 finished executing...");

      final response = await http.get(
        Uri.parse('http://192.168.4.1/status'),
        headers: {'Connection': 'close'},
      ).timeout(Duration(seconds: 3));

      if (response.statusCode == 200) {
        print("📊 ESP32 status: ${response.body}");

        if (response.body.contains('"busy":false') || response.body.contains('"status":"idle"')) {
          setState(() {
            responseMessage = responseMessage! + "\n🤖 ESP32 confirmed: Drawing completed!";
          });
        }
      }
    } catch (e) {
      print("ℹ️ Could not check ESP32 completion status: $e");
    }
  }

  Future<void> _sendToESPOptimized() async {
    if (!_isESPConnected) {
      setState(() {
        responseMessage = "ESP32 not connected! Check connection first.";
      });
      return;
    }

    if (_isSendingCommands) {
      setState(() {
        responseMessage = "Commands already being sent! Please wait...";
      });
      return;
    }

    setState(() {
      _isSendingCommands = true;
    });

    try {
      List<Map<String, dynamic>> commands = _extractCommandsOnce();

      if (commands.isEmpty) {
        setState(() {
          responseMessage = "No valid commands to send!";
          _isSendingCommands = false;
        });
        return;
      }

      List<Map<String, dynamic>> optimizedCommands = _groupSimilarCommands(commands);

      print("🔍 Original commands: ${commands.length}");
      print("🔍 Optimized commands: ${optimizedCommands.length}");
      print("🔍 Drawing scale: $_drawingScale");

      setState(() {
        responseMessage = "Sending ${optimizedCommands.length} scaled commands (scale: ${_drawingScale}x)...";
      });

      int successCount = 0;
      int failCount = 0;
      Stopwatch stopwatch = Stopwatch()..start();

      for (int i = 0; i < optimizedCommands.length; i++) {
        Map<String, dynamic> command = optimizedCommands[i];

        int angle = command['angle'];
        int repeats = command['repeats'];

        print("📤 Sending scaled command ${i + 1}/${optimizedCommands.length}: Angle=$angle, Repeats=$repeats (Scale: $_drawingScale)");

        bool success = await _sendSingleCommandWithRetry(angle, repeats, i + 1);

        if (success) {
          successCount++;
          print("✅ Command ${i + 1} completed successfully");
        } else {
          failCount++;
          print("❌ Command ${i + 1} failed after retries");
        }

        if (success && i < optimizedCommands.length - 1) {
          int smartDelay = _calculateSmartDelay(repeats);
          print("⏳ Smart delay: ${smartDelay}ms for $repeats repeats");

          setState(() {
            responseMessage = "Command ${i + 1}/${optimizedCommands.length} sent. Waiting ${smartDelay}ms...";
          });

          await Future.delayed(Duration(milliseconds: smartDelay));
        }

        double progress = ((i + 1) / optimizedCommands.length * 100);
        double elapsedSeconds = stopwatch.elapsedMilliseconds / 1000;
        setState(() {
          responseMessage = "Progress: ${progress.toStringAsFixed(0)}% (✅$successCount ❌$failCount) - ${elapsedSeconds.toStringAsFixed(1)}s - Scale: ${_drawingScale}x";
        });
      }

      stopwatch.stop();
      double totalTimeSeconds = stopwatch.elapsedMilliseconds / 1000;

      setState(() {
        if (failCount == 0) {
          responseMessage = "🎉 ALL SCALED COMMANDS COMPLETED! ✅$successCount sent in ${totalTimeSeconds.toStringAsFixed(1)}s (Scale: ${_drawingScale}x). Robot finished drawing!";
        } else {
          responseMessage = "⚠️ Completed with issues: ✅$successCount successful, ❌$failCount failed in ${totalTimeSeconds.toStringAsFixed(1)}s";
        }
      });

      await _checkIfESPFinished();

    } catch (e) {
      setState(() {
        responseMessage = "💥 Error during sending: $e";
      });
    } finally {
      setState(() {
        _isSendingCommands = false;
      });
    }
  }

  String _getProcessingMethod() {
    if (_useServerProcessing && _serverResult != null && _serverResult!.success) {
      return "Python Server (Advanced)";
    }
    return "Local Processing";
  }

  String _getStrokesCount() {
    if (_serverResult != null && _serverResult!.success) {
      return "${_serverResult!.optimizationStats['optimized_strokes'] ?? _serverResult!.optimizedStrokes.length}";
    }
    return "${_processingStats['optimizedStrokes'] ?? _extractedStrokes.length}";
  }

  String _getTotalLength() {
    if (_serverResult != null && _serverResult!.success) {
      final distance = _serverResult!.optimizationStats['total_distance_mm'];
      if (distance != null) {
        return "${distance}mm";
      }
    }
    return "${_processingStats['totalLength'] ?? 0}px";
  }

  Widget _buildScalePresetButton(String label, double scale) {
    bool isSelected = (_drawingScale - scale).abs() < 0.05;

    return GestureDetector(
      onTap: _isSendingCommands ? null : () {
        setState(() {
          _drawingScale = scale;
          _lastProcessedCommands.clear();
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
              const SizedBox(height: 10),

              // ESP Connection Status
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                    SizedBox(width: 8),
                    Text(
                      _isESPConnected ? "ESP32 Connected" : "ESP32 Disconnected",
                      style: GoogleFonts.audiowide(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _isESPConnected ? Colors.green.shade700 : Colors.red.shade700,
                      ),
                    ),
                    SizedBox(width: 8),
                    GestureDetector(
                      onTap: _checkESPConnection,
                      child: Icon(
                        Icons.refresh,
                        color: _isESPConnected ? Colors.green : Colors.red,
                        size: 16,
                      ),
                    ),
                  ],
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

              // Server Processing Toggle
              if (_image != null) ...[
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
                          Icon(Icons.cloud, color: Colors.blue.shade700, size: 20),
                          SizedBox(width: 8),
                          Text(
                            "Processing Method",
                            style: GoogleFonts.audiowide(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              "Use Python Server",
                              style: GoogleFonts.audiowide(
                                fontSize: 14,
                                color: Colors.blue.shade600,
                              ),
                            ),
                          ),
                          Switch(
                            value: _useServerProcessing,
                            activeColor: Colors.blue.shade600,
                            onChanged: isLoading ? null : (value) {
                              setState(() {
                                _useServerProcessing = value;
                                _lastProcessedCommands.clear();
                              });
                            },
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        _useServerProcessing 
                            ? "Advanced path optimization on Python server"
                            : "Local image processing",
                        style: GoogleFonts.audiowide(
                          fontSize: 12,
                          color: Colors.blue.shade500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (_serverResult != null && _serverResult!.success) ...[
                        SizedBox(height: 12),
                        Text(
                          "Current: ${_getProcessingMethod()}",
                          style: GoogleFonts.audiowide(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: 20),
              ],

              // Scale Control Section
              if (_extractedStrokes.isNotEmpty) ...[
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
                              onChanged: _isSendingCommands ? null : (value) {
                                setState(() {
                                  _drawingScale = value;
                                  _lastProcessedCommands.clear();
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
                  ElevatedButton.icon(
                    onPressed: (isLoading || _isSendingCommands) ? null : _pickImage,
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
                    onPressed: (isLoading || _image == null || selectedImage == null || _isSendingCommands) ? null : _processImage,
                    icon: isLoading
                        ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                        : Icon(_useServerProcessing ? Icons.cloud_sync : Icons.auto_fix_high, size: 18, color: Colors.white),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: uploadButtonColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                    ),
                    label: Text(
                      isLoading ? "Processing..." : (_useServerProcessing ? "Server Process" : "Local Process"),
                      style: GoogleFonts.audiowide(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),

                  if (_extractedStrokes.isNotEmpty) ...[
                    ElevatedButton.icon(
                      onPressed: (_isESPConnected && !_isSendingCommands) ? _sendToESPOptimized : null,
                      icon: _isSendingCommands
                          ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                          : Icon(Icons.send, size: 18, color: Colors.white),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: (_isESPConnected && !_isSendingCommands) ? Colors.green : Colors.grey,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                      ),
                      label: Text(
                        _isSendingCommands
                            ? "Sending..."
                            : _isESPConnected
                            ? "Send to Robot"
                            : "ESP32 not connected",
                        style: GoogleFonts.audiowide(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 20),

              // Processing stats
              if (_processingStats.isNotEmpty || (_serverResult != null && _serverResult!.optimizationStats.isNotEmpty)) ...[
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
                            "Processing Results - ${_getProcessingMethod()}",
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
                                "${_getStrokesCount()}",
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
                                "${_getTotalLength()}",
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
                          if (_serverResult != null && _serverResult!.optimizationStats.containsKey('efficiency_ratio')) ...[
                            Column(
                              children: [
                                Text(
                                  "${_serverResult!.optimizationStats['efficiency_ratio']}%",
                                  style: GoogleFonts.audiowide(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.purple.shade700,
                                  ),
                                ),
                                Text(
                                  "Efficiency",
                                  style: GoogleFonts.audiowide(fontSize: 12, color: Colors.purple.shade600),
                                ),
                              ],
                            ),
                          ],
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
                      _useServerProcessing ? "Processing on server..." : "Processing image...",
                      style: GoogleFonts.audiowide(fontSize: 16, color: uploadButtonColor),
                    ),
                    SizedBox(height: 5),
                    Text(
                      _useServerProcessing ? "Server processing may take longer" : "This may take a few seconds",
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
                    color: responseMessage!.contains("successfully") || responseMessage!.contains("Connected") || responseMessage!.contains("🎉") || responseMessage!.contains("🚀") || responseMessage!.contains("COMPLETED") || responseMessage!.contains("Server processing completed")
                        ? Colors.green.shade50
                        : responseMessage!.contains("Error") || responseMessage!.contains("failed") || responseMessage!.contains("Cannot") || responseMessage!.contains("❌")
                        ? Colors.red.shade50
                        : responseMessage!.contains("Optimized") || responseMessage!.contains("Progress") || responseMessage!.contains("Parallel") || responseMessage!.contains("Sending") || responseMessage!.contains("Scale") || responseMessage!.contains("server")
                        ? Colors.orange.shade50
                        : Colors.blue.shade50,
                    border: Border.all(
                      color: responseMessage!.contains("successfully") || responseMessage!.contains("Connected") || responseMessage!.contains("🎉") || responseMessage!.contains("🚀") || responseMessage!.contains("COMPLETED") || responseMessage!.contains("Server processing completed")
                          ? Colors.green.shade300
                          : responseMessage!.contains("Error") || responseMessage!.contains("failed") || responseMessage!.contains("Cannot") || responseMessage!.contains("❌")
                          ? Colors.red.shade300
                          : responseMessage!.contains("Optimized") || responseMessage!.contains("Progress") || responseMessage!.contains("Parallel") || responseMessage!.contains("Sending") || responseMessage!.contains("Scale") || responseMessage!.contains("server")
                          ? Colors.orange.shade300
                          : Colors.blue.shade300,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        responseMessage!.contains("successfully") || responseMessage!.contains("Connected") || responseMessage!.contains("🎉") || responseMessage!.contains("🚀") || responseMessage!.contains("COMPLETED") || responseMessage!.contains("Server processing completed")
                            ? Icons.check_circle
                            : responseMessage!.contains("Error") || responseMessage!.contains("failed") || responseMessage!.contains("Cannot") || responseMessage!.contains("❌")
                            ? Icons.error
                            : responseMessage!.contains("Progress") || responseMessage!.contains("Sending") || responseMessage!.contains("Parallel")
                            ? Icons.sync
                            : responseMessage!.contains("Optimized") || responseMessage!.contains("Scale") || responseMessage!.contains("server")
                            ? Icons.speed
                            : Icons.info,
                        color: responseMessage!.contains("successfully") || responseMessage!.contains("Connected") || responseMessage!.contains("🎉") || responseMessage!.contains("🚀") || responseMessage!.contains("COMPLETED") || responseMessage!.contains("Server processing completed")
                            ? Colors.green.shade700
                            : responseMessage!.contains("Error") || responseMessage!.contains("failed") || responseMessage!.contains("Cannot") || responseMessage!.contains("❌")
                            ? Colors.red.shade700
                            : responseMessage!.contains("Optimized") || responseMessage!.contains("Progress") || responseMessage!.contains("Parallel") || responseMessage!.contains("Sending") || responseMessage!.contains("Scale") || responseMessage!.contains("server")
                            ? Colors.orange.shade700
                            : Colors.blue.shade700,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          responseMessage!,
                          style: GoogleFonts.audiowide(
                            fontSize: 14,
                            color: responseMessage!.contains("successfully") || responseMessage!.contains("Connected") || responseMessage!.contains("🎉") || responseMessage!.contains("🚀") || responseMessage!.contains("COMPLETED") || responseMessage!.contains("Server processing completed")
                                ? Colors.green.shade700
                                : responseMessage!.contains("Error") || responseMessage!.contains("failed") || responseMessage!.contains("Cannot") || responseMessage!.contains("❌")
                                ? Colors.red.shade700
                                : responseMessage!.contains("Optimized") || responseMessage!.contains("Progress") || responseMessage!.contains("Parallel") || responseMessage!.contains("Sending") || responseMessage!.contains("Scale") || responseMessage!.contains("server")
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
}