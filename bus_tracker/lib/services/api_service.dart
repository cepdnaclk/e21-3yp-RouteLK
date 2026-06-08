// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String _base =
      'https://84pftvmo2d.execute-api.eu-north-1.amazonaws.com/prod';

  // ── Email normalization ────────────────────────────────────────────
  static String _normalizeEmail(String email) => email.trim().toLowerCase();

  // ── Deep cast helper ───────────────────────────────────────────────
  static Map<String, dynamic> _deepCast(dynamic item) {
    if (item is Map) {
      return item.map((key, value) {
        if (value is Map) return MapEntry(key.toString(), _deepCast(value));
        if (value is List) {
          return MapEntry(
            key.toString(),
            value.map((v) => v is Map ? _deepCast(v) : v).toList(),
          );
        }
        return MapEntry(key.toString(), value);
      });
    }
    return {};
  }

  // ── Register bus ───────────────────────────────────────────────────
  static Future<Map<String, dynamic>> registerBus(
      Map<String, dynamic> payload) async {
    if (payload.containsKey('operator_email')) {
      payload['operator_email'] =
          _normalizeEmail(payload['operator_email'] as String);
    }
    print('=== REGISTER BUS REQUEST ===');
    print('URL: $_base/operator/buses/register');
    print('Payload: ${jsonEncode(payload)}');

    final res = await http.post(
      Uri.parse('$_base/operator/buses/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    print('=== REGISTER BUS RESPONSE ===');
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
    if (res.statusCode == 200) return _deepCast(data);
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

  // ── Delete user from database (passengers, drivers, bus operators) ─
  // Uses the generic soft-delete lambda with POOL_TABLE_MAP.
  // Sets is_deleted=true in the correct table based on userPoolId.
  // Called BEFORE cognitoUser.deleteUser() so Cognito stays intact if DB fails.
  static Future<void> deleteUserFromDb(
      String email, String userPoolId) async {
    final normalizedEmail = _normalizeEmail(email);
    print('=== DELETE USER FROM DB ===');
    print('Email: $normalizedEmail | Pool: $userPoolId');

    final res = await http.post(
      Uri.parse('$_base/account/delete'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email'     : normalizedEmail,
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

  // ── Deactivate all buses for a bus operator ────────────────────────
  // Called ONLY for bus operators, AFTER deleteUserFromDb succeeds.
  // Hits the operator lambda which sets approved=false on all their buses.
  // Kept separate so the generic soft-delete (above) stays unchanged and
  // continues working for passengers and drivers as before.
  static Future<void> deactivateBusOperatorBuses(String email) async {
    final normalizedEmail = _normalizeEmail(email);
    print('=== DEACTIVATE BUS OPERATOR BUSES ===');
    print('Email: $normalizedEmail');

    final res = await http.put(
      Uri.parse('$_base/operator/account/delete'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': normalizedEmail}),
    );

    print('Status code: ${res.statusCode}');
    print('Response body: ${res.body}');

    if (res.statusCode != 200) {
      final data = jsonDecode(res.body);
      throw Exception(data['error'] ?? 'Bus deactivation failed');
    }
  }

  // ── Get all my buses by email ──────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getMyBuses(String email) async {
    print('=== GET MY BUSES ===');
    final normalizedEmail = _normalizeEmail(email);
    print('Email: $normalizedEmail');

    final encodedEmail = Uri.encodeComponent(normalizedEmail);

    try {
      final res = await http.get(
        Uri.parse('$_base/operator/buses/mine/$encodedEmail'),
        headers: {'Content-Type': 'application/json'},
      );

      print('Status code: ${res.statusCode}');
      print('Response body: ${res.body}');

      if (res.statusCode == 200) {
        final dynamic decoded = jsonDecode(res.body);

        if (decoded == null)           return [];
        if (decoded is! List)          return [];
        if ((decoded as List).isEmpty) return [];

        final result = decoded.map<Map<String, dynamic>>((item) {
          return _deepCast(item);
        }).toList();

        print('=== BUSES LOADED: ${result.length} ===');
        for (final b in result) {
          print(
            '  Bus: ${b['bus']?['bus_number']} '
            '— approved: ${b['bus']?['approved']}',
          );
        }

        return result;
      }

      print('=== getMyBuses non-200: ${res.statusCode} ===');
      return [];
    } catch (e) {
      print('=== getMyBuses error: $e ===');
      return [];
    }
  }
}