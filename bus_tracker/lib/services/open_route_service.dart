import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class RouteEstimate {
  final double distanceKm;
  final double durationMinutes;
  final List<LatLng> routePoints;

  const RouteEstimate({
    required this.distanceKm,
    required this.durationMinutes,
    this.routePoints = const [],
  });
}

class OpenRouteService {
  static const String _baseUrl = 'https://router.project-osrm.org/route/v1';

  Future<RouteEstimate> fetchEtaAndDistance({
    required LatLng from,
    required LatLng to,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/driving/${from.longitude},${from.latitude};${to.longitude},${to.latitude}'
      '?overview=full&geometries=geojson&steps=false&annotations=false&alternatives=false',
    );

    http.Response response;
    try {
      response = await http
          .get(uri, headers: {'Accept': 'application/json'})
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
        'OSRM non-2xx response: ${response.statusCode} ${response.body}',
      );
      throw Exception('OSRM request failed: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final routes = decoded['routes'] as List<dynamic>?;

    if (routes == null || routes.isEmpty) {
      debugPrint('OSRM unexpected payload: ${response.body}');
      throw Exception('Route summary is missing from OSRM response.');
    }

    final summary = routes.first as Map<String, dynamic>;
    final distanceMeters = (summary['distance'] as num?)?.toDouble();
    final durationSeconds = (summary['duration'] as num?)?.toDouble();
    final routePoints = _extractRoutePoints(summary['geometry']);

    if (distanceMeters == null || durationSeconds == null) {
      throw Exception('Distance or duration missing in route summary.');
    }

    return RouteEstimate(
      distanceKm: distanceMeters / 1000,
      durationMinutes: durationSeconds / 60,
      routePoints: routePoints,
    );
  }

  List<LatLng> _extractRoutePoints(dynamic geometry) {
    final coordinates = geometry is Map<String, dynamic>
        ? geometry['coordinates'] as List<dynamic>?
        : null;

    if (coordinates == null || coordinates.isEmpty) {
      return const [];
    }

    return coordinates
        .map((point) {
          if (point is List<dynamic> && point.length >= 2) {
            final longitude = (point[0] as num).toDouble();
            final latitude = (point[1] as num).toDouble();
            return LatLng(latitude, longitude);
          }
          return null;
        })
        .whereType<LatLng>()
        .toList();
  }
}
