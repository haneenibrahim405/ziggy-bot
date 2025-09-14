// python_server_service.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

class PythonServerService {
  static const String serverUrl = 'http://YOUR_PYTHON_SERVER_IP:8000'; // Replace with actual IP
  
  /// Upload image to Python server and get optimized strokes
  static Future<ServerProcessingResult> processImageOnServer(img.Image image) async {
    try {
      // Convert image to bytes
      Uint8List imageBytes = Uint8List.fromList(img.encodePng(image));
      
      // Create multipart request
      var request = http.MultipartRequest(
        'POST', 
        Uri.parse('$serverUrl/upload/')
      );
      
      // Add image file
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          imageBytes,
          filename: 'upload.png',
        ),
      );
      
      print("📤 Sending image to Python server...");
      
      // Send request with timeout
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
  
  /// Convert server response to ESP32 commands
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
        
        // Calculate movement vector
        double dx = (point2[0] - point1[0]) * scale;
        double dy = (point2[1] - point1[1]) * scale;
        
        // Calculate distance and angle
        double distance = (dx * dx + dy * dy).sqrt();
        double angleRad = (dy / dx).atan2();
        int angleDeg = (angleRad * 180 / 3.14159).round() % 360;
        if (angleDeg < 0) angleDeg += 360;
        
        // Convert distance to repeats (assuming 1 repeat = ~1mm)
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
  
  /// Optimize commands by grouping similar angles
  static List<Map<String, dynamic>> _optimizeCommands(List<Map<String, dynamic>> commands) {
    if (commands.isEmpty) return [];
    
    List<Map<String, dynamic>> optimized = [];
    Map<String, dynamic> current = Map.from(commands[0]);
    
    for (int i = 1; i < commands.length; i++) {
      var next = commands[i];
      
      // If same angle, combine repeats
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
    const int baseTimePerRepeat = 150; // ms
    const int setupTime = 50;
    return setupTime + (repeats * baseTimePerRepeat);
  }
}

/// Result class for server processing
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