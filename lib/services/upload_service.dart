import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class UploadService {
  final String baseUrl = "http://192.168.1.58:8000";

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
        return "Uploaded! Found ${data["stroke_count"]} strokes.";
      } else {
        final errorData = jsonDecode(resString);
        return "Upload failed: ${errorData["error"] ?? "Unknown error"}";
      }
    } on SocketException {
      return "Connection error: Cannot connect to server. Make sure the server is running.";
    } on HttpException {
      return "HTTP error: Could not connect to the server.";
    } on FormatException {
      return "Format error: Invalid response from server.";
    } catch (e) {
      return "Unexpected error: ${e.toString()}";
    }
  }
}
