import 'package:http/http.dart' as http;

class ConnectionService {
  final String baseUrl;

  ConnectionService({required this.baseUrl});

  Future<bool> toggle(bool isOn) async {
    final url = Uri.parse("$baseUrl/${isOn ? "connect" : "disconnect"}");
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 1));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
