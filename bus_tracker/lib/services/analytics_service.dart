import 'dart:convert';
import 'package:http/http.dart' as http;

class AnalyticsService {
  static const String _baseUrl =
      'https://grcwv997gb.execute-api.eu-north-1.amazonaws.com/prod';

  static Future<Map<String, dynamic>> getAnalytics(String busId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/analytics?bus_id=$busId'),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to load analytics');
    }
  }
}
