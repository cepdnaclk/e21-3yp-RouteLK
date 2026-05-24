import 'dart:async';
import 'dart:developer' as developer;
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

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
    final body = <String, dynamic>{
      'query': query,
    };

    if (variables != null) {
      body['variables'] = variables;
    }

    return jsonEncode(body);
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
        developer.log('Error loading bus locations from AppSync: $error');
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
    required int passengerId,
    required LatLng location,
    String? route,
  }) async {
    final mutation = '''
      mutation CreateBusPickup {
        createBusPickup(input: {
          busId: ${jsonEncode(busId)}
          passengerId: $passengerId
          latitude: ${location.latitude}
          longitude: ${location.longitude}
        }) {
          pickId
          busId
          passengerId
          latitude
          longitude
          status
          timestamp
        }
      }
    ''';

    final data = await _postGraphql(mutation);
    final createdPickup = data['createBusPickup'];
    if (createdPickup is! Map<String, dynamic>) {
      throw Exception('AppSync pickup mutation returned an unexpected payload');
    }
  }

  Future<List<Map<String, dynamic>>> _fetchBusPickups(String busId) async {
    final query = '''
      query GetBusPickups {
        getBusPickups(busId: ${jsonEncode(busId)}) {
          pickId
          latitude
          longitude
          status
        }
      }
    ''';

    final data = await _postGraphql(query);
    final pickups = data['getBusPickups'];
    if (pickups is! List) {
      return <Map<String, dynamic>>[];
    }

    return pickups.whereType<Map<String, dynamic>>().toList();
  }

  Uri _buildAppSyncRealtimeUri() {
    final graphqlUri = Uri.parse(_appSyncEndpoint);
    final realtimeHost = graphqlUri.host.replaceFirst(
      'appsync-api.',
      'appsync-realtime-api.',
    );

    return Uri(
      scheme: 'wss',
      host: realtimeHost,
      path: graphqlUri.path,
      queryParameters: <String, String>{
        'header': base64Encode(
          utf8.encode(
            jsonEncode(<String, String>{
              'host': graphqlUri.host,
              'x-api-key': _appSyncApiKey,
            }),
          ),
        ),
        'payload': base64Encode(utf8.encode('{}')),
      },
    );
  }

  String _buildCreateBusPickupSubscription(String busId) {
    return '''
      subscription OnCreateBusPickup {
        onCreateBusPickup(busId: ${jsonEncode(busId)}) {
          pickId
          busId
          passengerId
          latitude
          longitude
          status
          timestamp
        }
      }
    ''';
  }

  Map<String, LatLng> _pickupMapFromEvent(
    Map<String, dynamic> pickup,
    Map<String, LatLng> currentMap,
  ) {
    final status = (pickup['status'] as String?)?.toLowerCase() ?? 'pending';
    if (status == 'cancelled') {
      return currentMap;
    }

    final pickId = (pickup['pickId'] as String?)?.trim();
    final latitude = (pickup['latitude'] as num?)?.toDouble();
    final longitude = (pickup['longitude'] as num?)?.toDouble();

    if (pickId == null || pickId.isEmpty || latitude == null || longitude == null) {
      return currentMap;
    }

    final nextMap = Map<String, LatLng>.from(currentMap);
    nextMap[pickId] = LatLng(latitude, longitude);
    return nextMap;
  }

  Map<String, LatLng> _pickupMapFromRecords(
    Iterable<Map<String, dynamic>> pickups,
  ) {
    final pickupMap = <String, LatLng>{};

    for (final pickup in pickups) {
      final nextMap = _pickupMapFromEvent(pickup, pickupMap);
      if (nextMap.length != pickupMap.length) {
        pickupMap
          ..clear()
          ..addAll(nextMap);
      }
    }

    return pickupMap;
  }

  /// Listen to pickup requests for a driver's bus.
  Stream<Map<String, LatLng>> listenToPickupRequestsForBus(String busId) {
    final normalizedBusId = busId.trim();
    if (normalizedBusId.isEmpty) {
      return Stream<Map<String, LatLng>>.value(<String, LatLng>{});
    }

    final controller = StreamController<Map<String, LatLng>>();
    final pickupMap = <String, LatLng>{};
    final subscriptionId =
        'pickup-${DateTime.now().microsecondsSinceEpoch}-${normalizedBusId.hashCode}';

    WebSocketChannel? channel;
    StreamSubscription? socketSubscription;
    Timer? keepAliveTimer;
    bool closed = false;
    int connectionTimeoutMs = 300000;

    void cancelKeepAliveTimer() {
      keepAliveTimer?.cancel();
      keepAliveTimer = null;
    }

    void scheduleKeepAliveTimeout() {
      cancelKeepAliveTimer();
      keepAliveTimer = Timer(
        Duration(milliseconds: connectionTimeoutMs),
        () {
          if (!closed) {
            socketSubscription?.cancel();
            channel?.sink.close();
          }
        },
      );
    }

    Future<void> closeStream({Object? error}) async {
      if (closed) {
        return;
      }
      closed = true;
      cancelKeepAliveTimer();
      await socketSubscription?.cancel();
      await channel?.sink.close();
      if (error != null && !controller.isClosed) {
        controller.addError(error);
      }
      if (!controller.isClosed) {
        await controller.close();
      }
    }

    void startSubscription() {
      final query = _buildCreateBusPickupSubscription(normalizedBusId);
      channel?.sink.add(
        jsonEncode(<String, dynamic>{
          'id': subscriptionId,
          'type': 'start',
          'payload': <String, dynamic>{
            'data': jsonEncode(<String, dynamic>{
              'query': query,
              'variables': <String, dynamic>{},
            }),
            'extensions': <String, dynamic>{
              'authorization': <String, dynamic>{
                'host': Uri.parse(_appSyncEndpoint).host,
                'x-api-key': _appSyncApiKey,
              },
            },
          },
        }),
      );
    }

    Future<void> handleMessage(dynamic message) async {
      if (message is! String) {
        return;
      }

      final decoded = jsonDecode(message);
      if (decoded is! Map<String, dynamic>) {
        return;
      }

      final type = decoded['type']?.toString();
      switch (type) {
        case 'connection_ack':
          final payload = decoded['payload'];
          if (payload is Map<String, dynamic>) {
            final timeout = payload['connectionTimeoutMs'];
            if (timeout is num && timeout > 0) {
              connectionTimeoutMs = timeout.toInt();
            }
          }
          scheduleKeepAliveTimeout();
          startSubscription();
          break;
        case 'ka':
          scheduleKeepAliveTimeout();
          break;
        case 'start_ack':
          break;
        case 'data':
          final payload = decoded['payload'];
          if (payload is! Map<String, dynamic>) {
            return;
          }

          final data = payload['data'];
          if (data is! Map<String, dynamic>) {
            return;
          }

          final pickup = data['onCreateBusPickup'];
          if (pickup is! Map<String, dynamic>) {
            return;
          }

          final pickupBusId = (pickup['busId'] as String?)?.trim();
          if (pickupBusId != normalizedBusId) {
            return;
          }

          final nextMap = _pickupMapFromEvent(pickup, pickupMap);
          if (nextMap == pickupMap) {
            return;
          }

          pickupMap
            ..clear()
            ..addAll(nextMap);
          if (!controller.isClosed) {
            controller.add(Map<String, LatLng>.unmodifiable(pickupMap));
          }
          break;
        case 'error':
        case 'connection_error':
          final payload = decoded['payload'];
          await closeStream(
            error: Exception('AppSync pickup subscription failed: $payload'),
          );
          break;
        case 'complete':
          await closeStream();
          break;
      }
    }

    Future<void> loadInitialPickups() async {
      try {
        final pickups = await _fetchBusPickups(normalizedBusId);
        if (closed || controller.isClosed) {
          return;
        }

        pickupMap
          ..clear()
          ..addAll(_pickupMapFromRecords(pickups));
        controller.add(Map<String, LatLng>.unmodifiable(pickupMap));
      } catch (error) {
        await closeStream(error: error);
        return;
      }

      try {
        final uri = _buildAppSyncRealtimeUri();
        channel = WebSocketChannel.connect(
          uri,
          protocols: const <String>['graphql-ws'],
        );

        socketSubscription = channel!.stream.listen(
          (message) {
            unawaited(handleMessage(message));
          },
          onError: (error) {
            unawaited(closeStream(error: error));
          },
          onDone: () {
            unawaited(closeStream());
          },
        );

        channel!.sink.add(jsonEncode(<String, dynamic>{'type': 'connection_init'}));
      } catch (error) {
        await closeStream(error: error);
      }
    }

    () async {
      await loadInitialPickups();
    }();

    controller.onCancel = () async {
      await closeStream();
    };

    return controller.stream;
  }

  /// Helper for future callers that need to parse a single bus location payload.
  BusData? parseBusLocationPayload(Map<String, dynamic> payload) {
    return _parseBusLocation(payload);
  }
}
