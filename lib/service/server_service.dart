import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class ServerService {
  // Server configuration
  static const String serverBaseUrl = 'http://192.168.1.7:8000'; // Change according to your server
  static const Duration requestTimeout = Duration(seconds: 60);

  // ESP32 configuration
  static const String espBaseUrl = 'http://192.168.4.1';
  static const Duration espTimeout = Duration(seconds: 10);

  /// Upload image to server for processing (legacy method)
  static Future<ServerProcessingResult> processImageOnServer(File imageFile) async {
    try {
      print("Uploading image to server for processing...");

      var request = http.MultipartRequest('POST', Uri.parse('$serverBaseUrl/upload/'));

      // Add image file
      request.files.add(
        await http.MultipartFile.fromPath(
          'upload_image',
          imageFile.path,
        ),
      );

      // Add headers
      request.headers.addAll({
        'Content-Type': 'multipart/form-data',
        'User-Agent': 'Flutter-SpideyDraw',
      });

      print("Sending request to server...");

      // Send request with timeout
      var streamedResponse = await request.send().timeout(requestTimeout);
      var response = await http.Response.fromStream(streamedResponse);

      print("Server response status: ${response.statusCode}");

      if (response.statusCode == 200) {
        Map<String, dynamic> jsonResponse = json.decode(response.body);

        print("Server processing successful");
        print("Optimized strokes: ${jsonResponse['total_strokes'] ?? 0}");

        return ServerProcessingResult(
          success: true,
          processedImageBase64: jsonResponse['processed_image'],
          optimizedStrokes: jsonResponse['optimized_strokes'],
          stats: jsonResponse['stats'],
          message: jsonResponse['message'] ?? 'Processing completed successfully',
          totalPoints: jsonResponse['total_points'],
          totalStrokes: jsonResponse['total_strokes'],
        );
      } else {
        String errorMessage = 'Server error: ${response.statusCode}';
        try {
          Map<String, dynamic> errorResponse = json.decode(response.body);
          errorMessage = errorResponse['error'] ?? errorMessage;
        } catch (e) {
          print("Could not parse error response");
        }

        return ServerProcessingResult(
          success: false,
          error: errorMessage,
        );
      }

    } catch (e) {
      print("❌ Server processing error: $e");
      return ServerProcessingResult(
        success: false,
        error: 'Failed to connect to server: $e',
      );
    }
  }

  /// NEW: Send image directly to robot with GRBL commands
  static Future<RobotSendResult> sendImageToRobot(File imageFile, {double scale = 1.0}) async {
    try {
      print("🤖 Sending image directly to robot with GRBL commands...");
      print("📏 Scale: ${scale}x");

      var request = http.MultipartRequest('POST', Uri.parse('$serverBaseUrl/send_to_robot/'));

      // Add image file
      request.files.add(
        await http.MultipartFile.fromPath(
          'image',
          imageFile.path,
        ),
      );

      // Add scale parameter
      request.fields['scale'] = scale.toString();

      // Add headers
      request.headers.addAll({
        'Content-Type': 'multipart/form-data',
        'User-Agent': 'Flutter-SpideyDraw-Robot',
      });

      print("Processing and sending GRBL commands to robot...");

      // Send request with extended timeout for robot operations
      var streamedResponse = await request.send().timeout(requestTimeout);
      var response = await http.Response.fromStream(streamedResponse);

      print("Robot response status: ${response.statusCode}");

      if (response.statusCode == 200) {
        Map<String, dynamic> jsonResponse = json.decode(response.body);

        print("Robot processing successful");
        print("GRBL commands sent: ${jsonResponse['stats']?['total_commands'] ?? 0}");

        return RobotSendResult(
          success: true,
          message: jsonResponse['message'] ?? 'GRBL commands sent successfully',
          processedImageBase64: jsonResponse['processed_image'],
          stats: jsonResponse['stats'],
          totalCommands: jsonResponse['stats']?['total_commands'] ?? 0,
          appliedScale: jsonResponse['stats']?['applied_scale'] ?? scale,
        );
      } else {
        String errorMessage = 'Robot error: ${response.statusCode}';
        try {
          Map<String, dynamic> errorResponse = json.decode(response.body);
          errorMessage = errorResponse['error'] ?? errorMessage;
        } catch (e) {
          print("Could not parse robot error response");
        }

        return RobotSendResult(
          success: false,
          error: errorMessage,
        );
      }

    } catch (e) {
      print("❌ Robot send error: $e");
      return RobotSendResult(
        success: false,
        error: 'Failed to send to robot: $e',
      );
    }
  }

  /// Send bulk data to ESP32 (legacy method - now deprecated in favor of GRBL)
  @deprecated
  static Future<ESPBulkSendResult> sendBulkDataToESP(Map<String, dynamic> bulkData, {double scale = 1.0}) async {
    try {
      if (bulkData.isEmpty || bulkData['strokes'] == null) {
        return ESPBulkSendResult(
          success: false,
          error: 'No valid bulk data to send',
        );
      }

      List<dynamic> strokes = bulkData['strokes'];
      if (strokes.isEmpty) {
        return ESPBulkSendResult(
          success: false,
          error: 'No strokes found in bulk data',
        );
      }

      print("Starting bulk send to ESP32...");
      print("Total strokes to send: ${strokes.length}");
      print("Applied scale: ${scale}x");

      // Prepare scaled bulk data
      Map<String, dynamic> scaledBulkData = _applyScaleToBulkData(bulkData, scale);

      // Send bulk data to ESP32
      final response = await http.post(
        Uri.parse('$espBaseUrl/draw/bulk'),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'Flutter-SpideyDraw',
          'Connection': 'close',
        },
        body: json.encode(scaledBulkData),
      ).timeout(espTimeout);

      if (response.statusCode == 200) {
        Map<String, dynamic> espResponse = json.decode(response.body);

        print("ESP32 bulk send successful");

        return ESPBulkSendResult(
          success: true,
          message: 'Bulk data sent successfully to robot',
          espResponse: espResponse,
          totalStrokes: scaledBulkData['total_strokes'],
          totalPoints: scaledBulkData['total_points'],
          appliedScale: scale,
        );
      } else {
        return ESPBulkSendResult(
          success: false,
          error: 'ESP32 responded with status ${response.statusCode}',
        );
      }

    } catch (e) {
      print("❌ ESP32 bulk send error: $e");
      return ESPBulkSendResult(
        success: false,
        error: 'Failed to send bulk data to ESP32: $e',
      );
    }
  }

  /// Check ESP32 connection status
  static Future<bool> checkESPConnection() async {
    try {
      print("🔍 Checking ESP32 connection...");

      final response = await http.get(
        Uri.parse('$espBaseUrl/status'),
        headers: {'Connection': 'close'},
      ).timeout(Duration(seconds: 3));

      bool isConnected = response.statusCode == 200;
      print(isConnected ? "ESP32 connected" : "❌ ESP32 not responding");

      return isConnected;
    } catch (e) {
      print("❌ ESP32 connection failed: $e");
      return false;
    }
  }

  /// Apply scale to bulk data (legacy helper method)
  @deprecated
  static Map<String, dynamic> _applyScaleToBulkData(Map<String, dynamic> bulkData, double scale) {
    if (scale == 1.0) {
      return Map.from(bulkData);
    }

    Map<String, dynamic> scaledData = Map.from(bulkData);
    List<dynamic> originalStrokes = bulkData['strokes'];
    List<Map<String, dynamic>> scaledStrokes = [];

    int totalScaledPoints = 0;

    for (dynamic strokeData in originalStrokes) {
      if (strokeData is Map<String, dynamic>) {
        List<dynamic> originalPoints = strokeData['points'] ?? [];
        List<List<double>> scaledPoints = [];

        for (dynamic point in originalPoints) {
          if (point is List && point.length >= 2) {
            double x = (point[0] as num).toDouble() * scale;
            double y = (point[1] as num).toDouble() * scale;
            scaledPoints.add([x, y]);
          }
        }

        scaledStrokes.add({
          'stroke_id': strokeData['stroke_id'],
          'points': scaledPoints,
          'point_count': scaledPoints.length,
          'original_point_count': strokeData['point_count'],
          'applied_scale': scale,
        });

        totalScaledPoints += scaledPoints.length;
      }
    }

    scaledData['strokes'] = scaledStrokes;
    scaledData['total_points'] = totalScaledPoints;
    scaledData['applied_scale'] = scale;
    scaledData['original_total_points'] = bulkData['total_points'];

    print("🔧 Applied ${scale}x scale: ${bulkData['total_points']} -> $totalScaledPoints points");

    return scaledData;
  }

  /// Get server status
  static Future<bool> checkServerConnection() async {
    try {
      print("Checking server connection...");

      final response = await http.get(
        Uri.parse('$serverBaseUrl/upload/'),
        headers: {'User-Agent': 'Flutter-SpideyDraw'},
      ).timeout(Duration(seconds: 5));

      bool isConnected = response.statusCode == 200;
      print(isConnected ? "✅ Server connected" : "❌ Server not responding");

      return isConnected;
    } catch (e) {
      print("❌ Server connection failed: $e");
      return false;
    }
  }
}

/// Result class for server processing (legacy)
class ServerProcessingResult {
  final bool success;
  final String? error;
  final String? message;
  final String? processedImageBase64;
  final List<dynamic>? optimizedStrokes;
  final Map<String, dynamic>? stats;
  final int? totalPoints;
  final int? totalStrokes;

  ServerProcessingResult({
    required this.success,
    this.error,
    this.message,
    this.processedImageBase64,
    this.optimizedStrokes,
    this.stats,
    this.totalPoints,
    this.totalStrokes,
  });

  @override
  String toString() {
    if (success) {
      return 'ServerProcessingResult(success: true, strokes: $totalStrokes, points: $totalPoints)';
    } else {
      return 'ServerProcessingResult(success: false, error: $error)';
    }
  }
}

/// NEW: Result class for direct robot sending with GRBL
class RobotSendResult {
  final bool success;
  final String? error;
  final String? message;
  final String? processedImageBase64;
  final Map<String, dynamic>? stats;
  final int? totalCommands;
  final double? appliedScale;

  RobotSendResult({
    required this.success,
    this.error,
    this.message,
    this.processedImageBase64,
    this.stats,
    this.totalCommands,
    this.appliedScale,
  });

  @override
  String toString() {
    if (success) {
      return 'RobotSendResult(success: true, commands: $totalCommands, scale: ${appliedScale}x)';
    } else {
      return 'RobotSendResult(success: false, error: $error)';
    }
  }
}

/// Result class for ESP32 bulk sending (legacy - deprecated)
@deprecated
class ESPBulkSendResult {
  final bool success;
  final String? error;
  final String? message;
  final Map<String, dynamic>? espResponse;
  final int? totalStrokes;
  final int? totalPoints;
  final double? appliedScale;

  ESPBulkSendResult({
    required this.success,
    this.error,
    this.message,
    this.espResponse,
    this.totalStrokes,
    this.totalPoints,
    this.appliedScale,
  });

  @override
  String toString() {
    if (success) {
      return 'ESPBulkSendResult(success: true, strokes: $totalStrokes, points: $totalPoints, scale: ${appliedScale}x)';
    } else {
      return 'ESPBulkSendResult(success: false, error: $error)';
    }
  }
}