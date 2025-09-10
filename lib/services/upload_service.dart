import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class ProcessedImageResult {
  final String message;
  final List<List<List<double>>> allStrokes;
  final int strokeCount;
  final String processedImageBase64;

  ProcessedImageResult({
    required this.message,
    required this.allStrokes,
    required this.strokeCount,
    required this.processedImageBase64,
  });

  factory ProcessedImageResult.fromJson(Map<String, dynamic> json) {
    List<List<List<double>>> parsedStrokes = [];
    if (json['all_strokes'] != null) {
      for (var stroke in json['all_strokes']) {
        List<List<double>> currentStroke = [];
        for (var point in stroke) {
          currentStroke.add(List<double>.from(point));
        }
        parsedStrokes.add(currentStroke);
      }
    }

    return ProcessedImageResult(
      message: json['message'] ?? "No message",
      allStrokes: parsedStrokes,
      strokeCount: json['stroke_count'] ?? 0,
      processedImageBase64: json['processed_image'] ?? '',
    );
  }

  Uint8List? getProcessedImageBytes() {
    if (processedImageBase64.isEmpty) return null;
    return base64Decode(processedImageBase64);
  }
}

class UploadService {
  final String baseUrl = "http://192.168.1.5:8000";

  ProcessedImageResult? lastResult;

  Future<String> uploadImage(File image) async {
    try {
      var request = http.MultipartRequest(
        "POST",
        Uri.parse("$baseUrl/upload/"),
      );
      request.files.add(await http.MultipartFile.fromPath("image", image.path));

      var response = await request.send();
      final resString = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = jsonDecode(resString);
        lastResult = ProcessedImageResult.fromJson(data);
        return lastResult?.message ?? "Image uploaded successfully";
      } else {
        final errorData = jsonDecode(resString);
        return "Upload failed: ${errorData["error"] ?? "Unknown error"}";
      }
    } on SocketException {
      return "Connection error: Cannot connect to server.";
    } on HttpException {
      return "HTTP error: Could not connect to the server.";
    } on FormatException {
      return "Format error: Invalid response from server.";
    } catch (e) {
      return "Unexpected error: ${e.toString()}";
    }
  }
}
