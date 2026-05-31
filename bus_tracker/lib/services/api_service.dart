// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String _base =
      'https://84pftvmo2d.execute-api.eu-north-1.amazonaws.com/prod';

  // ── Register bus ───────────────────────────────────────────────────
  static Future<Map<String, dynamic>> registerBus(
      Map<String, dynamic> payload) async {
    print('=== REGISTER BUS REQUEST ===');
    print('URL: $_base/operator/buses/register');
    print('Payload: ${jsonEncode(payload)}');

    final res = await http.post(
      Uri.parse('$_base/operator/buses/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    print('Status code: ${res.statusCode}');
    print('Response body: ${res.body}');

    final data = jsonDecode(res.body);
    if (res.statusCode == 201) return data;
    throw Exception(data['error'] ?? data['message'] ?? 'Registration failed');
  }

  // ── Check approval status ──────────────────────────────────────────
  static Future<bool> checkApprovalStatus(String busId) async {
    print('=== CHECK APPROVAL STATUS ===');
    print('Bus ID: $busId');

    final res = await http.get(
      Uri.parse('$_base/operator/buses/status/$busId'),
      headers: {'Content-Type': 'application/json'},
    );

    print('Status code: ${res.statusCode}');
    print('Response body: ${res.body}');

    final data = jsonDecode(res.body);
    if (res.statusCode == 200) return data['approved'] as bool;
    throw Exception(data['error'] ?? 'Status check failed');
  }

  // ── Get full bus details ───────────────────────────────────────────
  static Future<Map<String, dynamic>> getBusDetails(String busId) async {
    print('=== GET BUS DETAILS ===');
    print('Bus ID: $busId');

    final res = await http.get(
      Uri.parse('$_base/operator/buses/details/$busId'),
      headers: {'Content-Type': 'application/json'},
    );

    print('Status code: ${res.statusCode}');
    print('Response body: ${res.body}');

    final data = jsonDecode(res.body);
    if (res.statusCode == 200) return data;
    throw Exception(data['error'] ?? 'Failed to load bus details');
  }

  // ── Update bus — instant (no re-approval) ─────────────────────────
  static Future<Map<String, dynamic>> updateBusInstant(
      Map<String, dynamic> payload) async {
    print('=== UPDATE BUS INSTANT ===');
    print('Payload: ${jsonEncode(payload)}');

    final res = await http.put(
      Uri.parse('$_base/operator/buses/update/instant'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    print('Status code: ${res.statusCode}');
    print('Response body: ${res.body}');

    final data = jsonDecode(res.body);
    if (res.statusCode == 200) return data;
    throw Exception(data['error'] ?? 'Update failed');
  }

  // ── Update bus — needs re-approval ────────────────────────────────
  static Future<Map<String, dynamic>> updateBusRequest(
      Map<String, dynamic> payload) async {
    print('=== UPDATE BUS REQUEST ===');
    print('Payload: ${jsonEncode(payload)}');

    final res = await http.put(
      Uri.parse('$_base/operator/buses/update/request'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    print('Status code: ${res.statusCode}');
    print('Response body: ${res.body}');

    final data = jsonDecode(res.body);
    if (res.statusCode == 200) return data;
    throw Exception(data['error'] ?? 'Update request failed');
  }

  // ── Delete user from database ──────────────────────────────────────
  // Called BEFORE cognitoUser.deleteUser() in CognitoAuthService.
  // Sends email + userPoolId so the Lambda knows which table to delete from.
  static Future<void> deleteUserFromDb(
      String email, String userPoolId) async {
    print('=== DELETE USER FROM DB ===');
    print('Email: $email | Pool: $userPoolId');

    final res = await http.post(
      Uri.parse('$_base/account/delete'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'userPoolId': userPoolId,
      }),
    );

    print('Status code: ${res.statusCode}');
    print('Response body: ${res.body}');

    if (res.statusCode != 200) {
      final data = jsonDecode(res.body);
      throw Exception(data['error'] ?? 'Account deletion from database failed');
    }
  }
}