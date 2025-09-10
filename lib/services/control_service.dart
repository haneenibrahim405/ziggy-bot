import 'package:http/http.dart' as http;

class ControlService {
  final String baseUrl = "http://192.168.1.100";
  DateTime? lastCommandTime;

  Future<void> sendCommand(String command) async {
    final now = DateTime.now();
    if (lastCommandTime != null &&
        now.difference(lastCommandTime!).inMilliseconds < 100) {
      return;
    }
    lastCommandTime = now;

    final url = Uri.parse("$baseUrl/$command");
    try {
      final response = await http.get(url).timeout(const Duration(milliseconds: 500));
      if (response.statusCode == 200) {
        print("Command sent: $command");
      } else {
        print("Error: ${response.statusCode}");
      }
    } catch (e) {
      print("Failed to send command: $e");
    }
  }
}
