import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class RouteEstimate {
  final double distanceKm;
  final double durationMinutes;

  const RouteEstimate({required this.distanceKm, required this.durationMinutes});
}

class OpenRouteService {
  static const String _baseUrl =
      'https://api.openrouteservice.org/v2/directions/driving-car';

  // TODO: Move to secure config/env before production release.
  static const String _apiKey =
      'eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6ImU4ODVmNjQzMjliODRkZjBiMzU1ZmI5NjIyOTQ5ZmNlIiwiaCI6Im11cm11cjY0In0=';

  Future<RouteEstimate> fetchEtaAndDistance({
    required LatLng from,
    required LatLng to,
  }) async {
    http.Response response;
    try {
      response = await http
          .post(
            Uri.parse(_baseUrl),
            headers: {
              'Authorization': _apiKey,
              'Content-Type': 'application/json',
              'Accept': 'application/json, application/geo+json',
            },
            body: jsonEncode({
              'coordinates': [
                [from.longitude, from.latitude],
                [to.longitude, to.latitude],
              ],
              'instructions': false,
              'geometry': false,
            }),
          )
          .timeout(const Duration(seconds: 12));
    } on SocketException {
      throw Exception('No internet connection.');
    } on HttpException {
      throw Exception('Network error while contacting route service.');
    } on FormatException {
      throw Exception('Invalid response from route service.');
    } on Exception catch (e) {
      throw Exception('Route service timeout or request error: $e');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      debugPrint(
        'OpenRouteService non-2xx response: ${response.statusCode} ${response.body}',
      );
      throw Exception('OpenRouteService request failed: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    Map<String, dynamic>? summary;

    final features = decoded['features'] as List<dynamic>?;
    if (features != null && features.isNotEmpty) {
      final properties = features.first['properties'] as Map<String, dynamic>?;
      summary = properties?['summary'] as Map<String, dynamic>?;
    }

    final routes = decoded['routes'] as List<dynamic>?;
    if (summary == null && routes != null && routes.isNotEmpty) {
      summary = routes.first['summary'] as Map<String, dynamic>?;
    }

    if (summary == null) {
      debugPrint('OpenRouteService unexpected payload: ${response.body}');
      throw Exception('Route summary is missing from OpenRouteService response.');
    }

    final distanceMeters = (summary['distance'] as num?)?.toDouble();
    final durationSeconds = (summary['duration'] as num?)?.toDouble();

    if (distanceMeters == null || durationSeconds == null) {
      throw Exception('Distance or duration missing in route summary.');
    }

    return RouteEstimate(
      distanceKm: distanceMeters / 1000,
      durationMinutes: durationSeconds / 60,
    );
  }
}
