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
}
