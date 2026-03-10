import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Bus data model to store location, passenger count, and route
class BusData {
  final LatLng location;
  final int passengers;
  final String route;

  BusData({
    required this.location,
    required this.passengers,
    required this.route,
  });

  /// Determine occupancy level and return color
  Color get occupancyColor {
    if (passengers < 20) {
      return Colors.green; // Low occupancy
    } else if (passengers < 40) {
      return Colors.orange; // Moderate occupancy
    } else {
      return Colors.red; // High occupancy
    }
  }

  String get occupancyLevel {
    if (passengers < 20) {
      return 'Low';
    } else if (passengers < 40) {
      return 'Moderate';
    } else {
      return 'High';
    }
  }
}
