import 'package:firebase_database/firebase_database.dart';
import 'package:latlong2/latlong.dart';
import '../models/bus_data.dart';

/// Service to handle Firebase Realtime Database operations for bus tracking
class FirebaseBusService {
  final DatabaseReference _busesRef = FirebaseDatabase.instance.ref('buses');

  /// Listen to Firebase Realtime Database for bus data updates
  /// Expected Firebase structure:
  /// buses/
  ///   bus1: { "latitude": 7.3, "longitude": 80.593, "passengers": 45, "route": "Kandy-Gampola" }
  ///   bus2: { "latitude": 7.35, "longitude": 80.6, "passengers": 15, "route": "Kandy-Peradeniya" }
  Stream<Map<String, BusData>> listenToBusLocations() {
    return _busesRef.onValue.map((DatabaseEvent event) {
      final data = event.snapshot.value;

      print('=== Firebase Data Received ===');
      print('Raw data: $data');
      print('Data type: ${data.runtimeType}');

      Map<String, BusData> busDataMap = {};

      if (data != null && data is Map) {
        data.forEach((key, value) {
          if (value is Map) {
            try {
              final lat = (value['latitude'] as num).toDouble();

              // Handle both 'longitude' and 'longitute' typo in Firebase
              final lng =
                  (value.containsKey('longitude')
                          ? value['longitude']
                          : value['longitute'])
                      as num;
              final lngDouble = lng.toDouble();

              // Get passenger count, default to 0 if not provided
              final passengers = (value['passengers'] as num?)?.toInt() ?? 0;

              // Get route, default to 'Unknown' if not provided
              final route = (value['route'] as String?) ?? 'Unknown';

              busDataMap[key.toString()] = BusData(
                location: LatLng(lat, lngDouble),
                passengers: passengers,
                route: route,
              );

              print(
                'Bus $key: $lat, $lngDouble, Passengers: $passengers, Route: $route',
              );
            } catch (e) {
              print('Error parsing bus $key: $e');
            }
          }
        });

        print('Total buses: ${busDataMap.length}');
        print('==============================');
      } else {
        print('No data received or data is not a Map');
        print('==============================');
      }

      return busDataMap;
    });
  }

  /// Get list of unique routes from bus data
  List<String> getAvailableRoutes(Map<String, BusData> busData) {
    return busData.values.map((bus) => bus.route).toSet().toList()..sort();
  }

  /// Filter buses by route
  Map<String, BusData> filterBusesByRoute(
    Map<String, BusData> busData,
    String? selectedRoute,
  ) {
    if (selectedRoute == null) {
      return busData; // Show all buses if no route selected
    }
    return Map.fromEntries(
      busData.entries.where((entry) => entry.value.route == selectedRoute),
    );
  }
}
