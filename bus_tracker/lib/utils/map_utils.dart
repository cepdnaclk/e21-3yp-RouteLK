import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/bus_data.dart';

/// Utility class for map operations
class MapUtils {
  /// Calculate bounds to fit all buses on the map
  static LatLngBounds calculateBusBounds(Map<String, BusData> buses) {
    if (buses.isEmpty) {
      throw Exception('Cannot calculate bounds for empty bus list');
    }

    final validLocations = buses.values
        .map((bus) => bus.location)
        .where(
          (location) =>
              location.latitude.isFinite && location.longitude.isFinite,
        )
        .toList();

    if (validLocations.isEmpty) {
      throw Exception('Cannot calculate bounds for invalid bus coordinates');
    }

    double minLat = validLocations.first.latitude;
    double maxLat = validLocations.first.latitude;
    double minLng = validLocations.first.longitude;
    double maxLng = validLocations.first.longitude;

    for (var location in validLocations) {
      if (location.latitude < minLat) minLat = location.latitude;
      if (location.latitude > maxLat) maxLat = location.latitude;
      if (location.longitude < minLng) minLng = location.longitude;
      if (location.longitude > maxLng) maxLng = location.longitude;
    }

    // Add padding to bounds
    final latSpan = (maxLat - minLat).abs();
    final lngSpan = (maxLng - minLng).abs();
    final latPadding = latSpan == 0 ? 0.005 : latSpan * 0.1;
    final lngPadding = lngSpan == 0 ? 0.005 : lngSpan * 0.1;

    return LatLngBounds(
      LatLng(minLat - latPadding, minLng - lngPadding),
      LatLng(maxLat + latPadding, maxLng + lngPadding),
    );
  }

  /// Fit the map camera to show all buses
  static void fitToBuses(
    MapController controller,
    Map<String, BusData> buses, {
    EdgeInsets padding = const EdgeInsets.all(50),
  }) {
    if (buses.isEmpty) return;

    if (buses.length == 1) {
      controller.move(buses.values.first.location, 16);
      return;
    }

    final bounds = calculateBusBounds(buses);
    controller.fitCamera(CameraFit.bounds(bounds: bounds, padding: padding));
  }

  /// Calculate bearing/heading angle in degrees (0-360) between two LatLng points
  static double calculateBearing(LatLng start, LatLng end) {
    final lat1 = start.latitude * pi / 180;
    final lon1 = start.longitude * pi / 180;
    final lat2 = end.latitude * pi / 180;
    final lon2 = end.longitude * pi / 180;

    final dLon = lon2 - lon1;

    final y = sin(dLon) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);

    final radians = atan2(y, x);
    return (radians * 180 / pi + 360) % 360;
  }
}
