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

    double minLat = buses.values.first.location.latitude;
    double maxLat = buses.values.first.location.latitude;
    double minLng = buses.values.first.location.longitude;
    double maxLng = buses.values.first.location.longitude;

    for (var bus in buses.values) {
      if (bus.location.latitude < minLat) minLat = bus.location.latitude;
      if (bus.location.latitude > maxLat) maxLat = bus.location.latitude;
      if (bus.location.longitude < minLng) minLng = bus.location.longitude;
      if (bus.location.longitude > maxLng) maxLng = bus.location.longitude;
    }

    // Add padding to bounds
    final latPadding = (maxLat - minLat) * 0.1;
    final lngPadding = (maxLng - minLng) * 0.1;

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

    final bounds = calculateBusBounds(buses);
    controller.fitCamera(CameraFit.bounds(bounds: bounds, padding: padding));
  }
}
