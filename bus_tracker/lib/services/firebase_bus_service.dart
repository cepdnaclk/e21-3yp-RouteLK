import 'dart:async';
import 'dart:convert';

import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/bus_data.dart';

/// Service to load bus locations from AppSync while preserving the existing API.
class FirebaseBusService {
  static const String _appSyncEndpoint =
      'https://tit2l4yfuff3bal65xlywdfjri.appsync-api.eu-north-1.amazonaws.com/graphql';
  static const String _appSyncApiKey = 'da2-ffyjjsjcobabji5z7zv7kdbhxi';
  static const String _routesEndpoint =
      'https://wk3cdtalw0.execute-api.eu-north-1.amazonaws.com/prod/routes';
  static const Duration _pollInterval = Duration(seconds: 5);
  static const int _busProbeLimit = 120;

  final DatabaseReference _pickupRequestsRef = FirebaseDatabase.instance.ref(
    'pickup_requests',
  );

  final Set<String> _knownBusIds = <String>{};

  Map<String, String> get _httpHeaders => <String, String>{
    'Content-Type': 'application/json',
    'x-api-key': _appSyncApiKey,
    'x-amz-user-agent': 'flutter-bus-tracker',
  };

  String _buildGraphqlBody({
    required String query,
    Map<String, dynamic>? variables,
  }) {
    return jsonEncode(<String, dynamic>{
      'query': query,
      if (variables != null) 'variables': variables,
    });
  }

  Future<Map<String, dynamic>> _postGraphql(
    String query, {
    Map<String, dynamic>? variables,
  }) async {
    final response = await http.post(
      Uri.parse(_appSyncEndpoint),
      headers: _httpHeaders,
      body: _buildGraphqlBody(query: query, variables: variables),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'AppSync request failed (${response.statusCode}): ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected AppSync response format');
    }

    final errors = decoded['errors'];
    if (errors is List && errors.isNotEmpty) {
      throw Exception('AppSync returned errors: $errors');
    }

    final data = decoded['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }

    return <String, dynamic>{};
  }

  List<String> _normalizeRoutes(dynamic value) {
    final rawRoutes = value is Map<String, dynamic> ? value['routes'] : value;

    if (rawRoutes is! List) {
      return <String>[];
    }

    final routes =
        rawRoutes
            .whereType<dynamic>()
            .map((route) => route.toString().trim())
            .where((route) => route.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    return routes;
  }

  /// Load available routes from the AWS API used by the frontend.
  Future<List<String>> fetchAvailableRoutes() async {
    final response = await http.get(Uri.parse(_routesEndpoint));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Route request failed (${response.statusCode}): ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    final routes = _normalizeRoutes(decoded);

    if (routes.isNotEmpty) {
      return routes;
    }

    throw Exception('Unexpected route response format');
  }

  Map<String, BusData> _parseBusEndpointResponse(
    dynamic decoded, {
    required String routeLabel,
  }) {
    final rawBuses = decoded is Map<String, dynamic> ? decoded['buses'] : null;
    if (rawBuses is! List) {
      return <String, BusData>{};
    }

    final busData = <String, BusData>{};
    for (final entry in rawBuses) {
      if (entry is! Map<String, dynamic>) {
        continue;
      }

      final latitude = _readDouble(entry, const ['lat', 'latitude']);
      final longitude = _readDouble(entry, const ['lon', 'lng', 'longitude']);
      final busId = _readString(entry, const ['busId', 'id']);

      if (latitude == null || longitude == null || busId == 'Unknown') {
        continue;
      }

      busData[busId] = BusData(
        location: LatLng(latitude, longitude),
        passengers: _readInt(entry, const ['passengers']),
        route: routeLabel,
        emergency: _parseEmergencyValue(entry['emergency']),
        speed: _readDouble(entry, const ['speed']),
        crowdLevel: _readString(entry, const ['crowdLevel']),
        updatedAt: _readTimestamp(entry, const ['updatedAt', 'timestamp']),
      );
    }

    return busData;
  }

  /// Load buses for the selected route from the AWS API used by the frontend.
  Future<Map<String, BusData>> fetchBusesForRoute(String? route) async {
    final uri = Uri.https(
      'wk3cdtalw0.execute-api.eu-north-1.amazonaws.com',
      '/prod/buses',
      route == null ? null : <String, String>{'route': route},
    );

    final response = await http.get(uri);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Bus request failed (${response.statusCode}): ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    final routeLabel = route == null || route.trim().isEmpty
        ? 'All Routes'
        : route.trim();

    return _parseBusEndpointResponse(decoded, routeLabel: routeLabel);
  }

  bool _parseEmergencyValue(dynamic value) {
    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == 'true' || normalized == '1' || normalized == 'yes';
    }

    return false;
  }

  bool _extractEmergencyFlag(Map<String, dynamic> value) {
    var hasEmergencyKey = false;
    var isEmergency = false;

    for (final entry in value.entries) {
      final key = entry.key.toString().trim().toLowerCase();
      if (key == 'emergency' || key.contains('emergency')) {
        hasEmergencyKey = true;
        isEmergency = isEmergency || _parseEmergencyValue(entry.value);
      }
    }

    if (!hasEmergencyKey) {
      return false;
    }

    return isEmergency;
  }

  String _readString(Map<String, dynamic> value, List<String> keys) {
    for (final key in keys) {
      final raw = value[key];
      if (raw is String && raw.trim().isNotEmpty) {
        return raw.trim();
      }
    }

    return 'Unknown';
  }

  double? _readDouble(Map<String, dynamic> value, List<String> keys) {
    for (final key in keys) {
      final raw = value[key];
      if (raw is num) {
        return raw.toDouble();
      }
      if (raw is String) {
        final parsed = double.tryParse(raw);
        if (parsed != null) {
          return parsed;
        }
      }
    }

    return null;
  }

  int _readInt(Map<String, dynamic> value, List<String> keys) {
    for (final key in keys) {
      final raw = value[key];
      if (raw is int) {
        return raw;
      }
      if (raw is num) {
        return raw.toInt();
      }
      if (raw is String) {
        final parsed = int.tryParse(raw);
        if (parsed != null) {
          return parsed;
        }
      }
    }

    return 0;
  }

  DateTime? _readTimestamp(Map<String, dynamic> value, List<String> keys) {
    for (final key in keys) {
      final raw = value[key];
      if (raw is int) {
        return DateTime.fromMillisecondsSinceEpoch(raw);
      }
      if (raw is num) {
        return DateTime.fromMillisecondsSinceEpoch(raw.toInt());
      }
      if (raw is String) {
        final parsedInt = int.tryParse(raw);
        if (parsedInt != null) {
          return DateTime.fromMillisecondsSinceEpoch(parsedInt);
        }

        final parsedDate = DateTime.tryParse(raw);
        if (parsedDate != null) {
          return parsedDate;
        }
      }
    }

    return null;
  }

  BusData? _parseBusLatest(Map<String, dynamic> value) {
    final latitude = _readDouble(value, const ['lat', 'latitude']);
    final longitude = _readDouble(value, const ['lon', 'lng', 'longitude']);

    if (latitude == null || longitude == null) {
      return null;
    }

    return BusData(
      location: LatLng(latitude, longitude),
      passengers: _readInt(value, const ['passengers']),
      route: 'Unknown',
      emergency: _extractEmergencyFlag(value),
      speed: _readDouble(value, const ['speed']),
      crowdLevel: _readString(value, const ['crowdLevel']),
      updatedAt: _readTimestamp(value, const ['updatedAt', 'timestamp']),
    );
  }

  BusData? _parseBusLocation(Map<String, dynamic> value) {
    final latitude = _readDouble(value, const ['lat', 'latitude']);
    final longitude = _readDouble(value, const ['lon', 'lng', 'longitude']);

    if (latitude == null || longitude == null) {
      return null;
    }

    return BusData(
      location: LatLng(latitude, longitude),
      passengers: _readInt(value, const ['passengers']),
      route: 'Unknown',
      emergency: _extractEmergencyFlag(value),
      speed: _readDouble(value, const ['speed']),
      crowdLevel: _readString(value, const ['crowdLevel']),
      updatedAt: _readTimestamp(value, const ['timestamp', 'updatedAt']),
    );
  }

  Iterable<String> _buildBusIdCandidates() sync* {
    for (var index = 1; index <= _busProbeLimit; index++) {
      yield index.toString().padLeft(2, '0');
      yield 'B${index.toString().padLeft(3, '0')}';
      yield 'bus$index';
    }
  }

  Future<BusData?> _fetchBusLatest(String busId) async {
    const query = r'''
      query GetBusLatest($busId: ID!) {
        getBusLatest(busId: $busId) {
          busId
          updatedAt
          lat
          lon
          passengers
          speed
          crowdLevel
          emergency
        }
      }
    ''';

    final data = await _postGraphql(
      query,
      variables: <String, dynamic>{'busId': busId},
    );

    final rawBus = data['getBusLatest'];
    if (rawBus is! Map<String, dynamic>) {
      return null;
    }

    return _parseBusLatest(rawBus);
  }

  Future<Map<String, BusData>> _discoverAndLoadBusLocations() async {
    final discovered = <String>{..._knownBusIds};

    if (discovered.isEmpty) {
      final probes = _buildBusIdCandidates().toList(growable: false);
      final probeResults = await Future.wait(
        probes.map((busId) async {
          try {
            final bus = await _fetchBusLatest(busId);
            return MapEntry(busId, bus);
          } catch (_) {
            return MapEntry(busId, null);
          }
        }),
      );

      for (final entry in probeResults) {
        if (entry.value != null) {
          discovered.add(entry.key);
        }
      }

      _knownBusIds.addAll(discovered);
    }

    if (discovered.isEmpty) {
      return <String, BusData>{};
    }

    final loaded = await Future.wait(
      discovered.map((busId) async {
        try {
          final bus = await _fetchBusLatest(busId);
          return MapEntry(busId, bus);
        } catch (_) {
          return MapEntry(busId, null);
        }
      }),
    );

    final busDataMap = <String, BusData>{};
    for (final entry in loaded) {
      final bus = entry.value;
      if (bus != null) {
        busDataMap[entry.key] = bus;
      }
    }

    _knownBusIds.addAll(busDataMap.keys);
    return busDataMap;
  }

  /// Poll AppSync for the latest bus locations.
  ///
  /// The current schema exposes per-bus reads, so this service discovers bus
  /// IDs once and then refreshes those IDs on a short interval.
  Stream<Map<String, BusData>> listenToBusLocations() async* {
    var refreshTick = 0;

    while (true) {
      try {
        if (_knownBusIds.isEmpty || refreshTick % 6 == 0) {
          final discovered = await _discoverAndLoadBusLocations();
          if (discovered.isNotEmpty) {
            yield discovered;
          } else {
            yield <String, BusData>{};
          }
        } else {
          final loaded = await Future.wait(
            _knownBusIds.map((busId) async {
              try {
                final bus = await _fetchBusLatest(busId);
                return MapEntry(busId, bus);
              } catch (_) {
                return MapEntry(busId, null);
              }
            }),
          );

          final busDataMap = <String, BusData>{};
          for (final entry in loaded) {
            final bus = entry.value;
            if (bus != null) {
              busDataMap[entry.key] = bus;
            }
          }

          if (busDataMap.isNotEmpty) {
            _knownBusIds.addAll(busDataMap.keys);
          }

          yield busDataMap;
        }
      } catch (error) {
        print('Error loading bus locations from AppSync: $error');
        yield <String, BusData>{};
      }

      refreshTick++;
      await Future<void>.delayed(_pollInterval);
    }
  }

  /// Get list of unique routes from bus data.
  List<String> getAvailableRoutes(Map<String, BusData> busData) {
    final routes =
        busData.values
            .map((bus) => bus.route)
            .where((route) => route.trim().isNotEmpty && route != 'Unknown')
            .toSet()
            .toList()
          ..sort();
    return routes;
  }

  /// Filter buses by route.
  Map<String, BusData> filterBusesByRoute(
    Map<String, BusData> busData,
    String? selectedRoute,
  ) {
    if (selectedRoute == null ||
        selectedRoute.trim().isEmpty ||
        selectedRoute == 'Unknown') {
      return busData;
    }

    return Map.fromEntries(
      busData.entries.where((entry) => entry.value.route == selectedRoute),
    );
  }

  /// Save a passenger pickup request for a specific bus.
  Future<void> createPickupRequest({
    required String busId,
    required LatLng location,
    String? route,
  }) async {
    final requestRef = _pickupRequestsRef.child(busId).push();
    await requestRef.set({
      'latitude': location.latitude,
      'longitude': location.longitude,
      'route': route,
      'status': 'pending',
      'timestamp': ServerValue.timestamp,
    });
  }

  /// Listen to pickup requests for a driver's bus.
  Stream<Map<String, LatLng>> listenToPickupRequestsForBus(String busId) {
    return _pickupRequestsRef.child(busId).onValue.map((event) {
      final rawData = event.snapshot.value;
      final pickupMap = <String, LatLng>{};

      if (rawData is! Map) {
        return pickupMap;
      }

      rawData.forEach((key, value) {
        if (value is! Map) {
          return;
        }

        try {
          final lat = (value['latitude'] as num).toDouble();
          final lng = (value['longitude'] as num).toDouble();
          final status =
              (value['status'] as String?)?.toLowerCase() ?? 'pending';

          if (status != 'cancelled') {
            pickupMap[key.toString()] = LatLng(lat, lng);
          }
        } catch (_) {
          // Skip malformed pickup records.
        }
      });

      return pickupMap;
    });
  }

  /// Helper for future callers that need to parse a single bus location payload.
  BusData? parseBusLocationPayload(Map<String, dynamic> payload) {
    return _parseBusLocation(payload);
  }
}
