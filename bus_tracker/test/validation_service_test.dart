// test/validation_service_test.dart

// Testing GitHub Actions CI workflow

import 'package:flutter_test/flutter_test.dart';
import 'package:bus_tracker/services/validation_service.dart';

void main() {
  group('3.1 Passenger Login Validation', () {
    // Mock database for login testing
    const registeredEmails = {'passenger@routelk.lk', 'user@example.com'};
    const credentialsDb = {
      'passenger@routelk.lk': 'Password123!',
      'user@example.com': 'ValidPass88',
    };

    Future<bool> mockCheckEmailRegistered(String email) async {
      return registeredEmails.contains(email.trim().toLowerCase());
    }

    Future<bool> mockAuthenticate(String email, String password) async {
      final normalized = email.trim().toLowerCase();
      return credentialsDb.containsKey(normalized) &&
          credentialsDb[normalized] == password;
    }

    group('Equivalence Partitions', () {
      test('Valid Class: Registered email with correct password', () async {
        final result = await ValidationService.loginPassenger(
          email: 'passenger@routelk.lk',
          password: 'Password123!',
          checkEmailRegistered: mockCheckEmailRegistered,
          authenticate: mockAuthenticate,
        );
        expect(result, isTrue);
      });

      test('Invalid Class: Incorrect password', () async {
        expect(
          () => ValidationService.loginPassenger(
            email: 'passenger@routelk.lk',
            password: 'WrongPassword',
            checkEmailRegistered: mockCheckEmailRegistered,
            authenticate: mockAuthenticate,
          ),
          throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('Incorrect password'))),
        );
      });

      test('Invalid Class: Unregistered email', () async {
        expect(
          () => ValidationService.loginPassenger(
            email: 'unregistered@example.com',
            password: 'SomePassword123',
            checkEmailRegistered: mockCheckEmailRegistered,
            authenticate: mockAuthenticate,
          ),
          throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('Unregistered email'))),
        );
      });

      test('Invalid Class: Empty credentials (empty email)', () async {
        expect(
          () => ValidationService.loginPassenger(
            email: '',
            password: 'Password123!',
            checkEmailRegistered: mockCheckEmailRegistered,
            authenticate: mockAuthenticate,
          ),
          throwsA(isA<ArgumentError>().having((e) => e.toString(), 'message', contains('Email cannot be empty'))),
        );
      });

      test('Invalid Class: Empty credentials (empty password)', () async {
        expect(
          () => ValidationService.loginPassenger(
            email: 'passenger@routelk.lk',
            password: '',
            checkEmailRegistered: mockCheckEmailRegistered,
            authenticate: mockAuthenticate,
          ),
          throwsA(isA<ArgumentError>().having((e) => e.toString(), 'message', contains('Password cannot be empty'))),
        );
      });
    });

    group('Boundary Value Analysis (Password Length)', () {
      test('Password length = 7 characters (Invalid)', () {
        expect(
          () => ValidationService.validateLoginPassword('1234567'),
          throwsA(isA<ArgumentError>().having((e) => e.toString(), 'message', contains('Password length = 7 characters (Invalid)'))),
        );
      });

      test('Password length = 8 characters (Minimum Valid)', () {
        expect(ValidationService.validateLoginPassword('12345678'), isTrue);
      });

      test('Password length = 32 characters (Maximum Valid)', () {
        expect(
          ValidationService.validateLoginPassword('a' * 32),
          isTrue,
        );
      });

      test('Password length = 33 characters (Invalid)', () {
        expect(
          () => ValidationService.validateLoginPassword('a' * 33),
          throwsA(isA<ArgumentError>().having((e) => e.toString(), 'message', contains('Password length = 33 characters (Invalid)'))),
        );
      });
    });

    group('Negative Test Cases', () {
      test('Null email', () {
        expect(
          () => ValidationService.validateLoginEmail(null),
          throwsA(isA<ArgumentError>().having((e) => e.toString(), 'message', contains('Email cannot be null'))),
        );
      });

      test('Null password', () {
        expect(
          () => ValidationService.validateLoginPassword(null),
          throwsA(isA<ArgumentError>().having((e) => e.toString(), 'message', contains('Password cannot be null'))),
        );
      });

      test('Invalid email formats', () {
        final invalidEmails = ['plainaddress', '@missingusername.com', 'username@.com', 'username@server', 'username@server..com'];
        for (final email in invalidEmails) {
          expect(
            () => ValidationService.validateLoginEmail(email),
            throwsA(isA<ArgumentError>().having((e) => e.toString(), 'message', contains('Invalid email format'))),
          );
        }
      });

      test('SQL injection strings', () {
        final sqlInjections = [
          "admin@example.com' OR '1'='1",
          "user@example.com' UNION SELECT NULL--",
          "test@example.com'; DROP TABLE passengers;--",
        ];
        for (final input in sqlInjections) {
          expect(
            () => ValidationService.validateLoginEmail(input),
            throwsA(isA<ArgumentError>().having((e) => e.toString(), 'message', contains('SQL injection strings detected'))),
          );
        }
      });

      test('Empty input fields', () async {
        expect(
          () => ValidationService.loginPassenger(
            email: '   ',
            password: 'Password123!',
            checkEmailRegistered: mockCheckEmailRegistered,
            authenticate: mockAuthenticate,
          ),
          throwsA(isA<ArgumentError>().having((e) => e.toString(), 'message', contains('Email cannot be empty'))),
        );
      });
    });
  });

  group('3.2 Search Bus', () {
    const registeredRoutes = ['1', '138', '120', '9999'];

    Future<List<String>> mockFetchRegisteredRoutes() async {
      return registeredRoutes;
    }

    group('Equivalence Partitions', () {
      test('Valid: Existing route number', () async {
        final result = await ValidationService.searchBus(
          route: '138',
          fetchRegisteredRoutes: mockFetchRegisteredRoutes,
        );
        expect(result, isTrue);
      });

      test('Invalid: Non-existing route', () async {
        expect(
          () => ValidationService.searchBus(
            route: '50',
            fetchRegisteredRoutes: mockFetchRegisteredRoutes,
          ),
          throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('Non-existing route'))),
        );
      });

      test('Invalid: Empty route', () async {
        expect(
          () => ValidationService.searchBus(
            route: '',
            fetchRegisteredRoutes: mockFetchRegisteredRoutes,
          ),
          throwsA(isA<ArgumentError>().having((e) => e.toString(), 'message', contains('Empty route'))),
        );
      });

      test('Invalid: Invalid route number format (non-numeric)', () async {
        expect(
          () => ValidationService.searchBus(
            route: 'route-one',
            fetchRegisteredRoutes: mockFetchRegisteredRoutes,
          ),
          throwsA(isA<ArgumentError>().having((e) => e.toString(), 'message', contains('Invalid route number'))),
        );
      });
    });

    group('Boundary Value Analysis', () {
      test('Route Number = 1', () async {
        final result = await ValidationService.searchBus(
          route: '1',
          fetchRegisteredRoutes: mockFetchRegisteredRoutes,
        );
        expect(result, isTrue);
      });

      test('Route Number = 9999', () async {
        final result = await ValidationService.searchBus(
          route: '9999',
          fetchRegisteredRoutes: mockFetchRegisteredRoutes,
        );
        expect(result, isTrue);
      });

      test('Route Number = 0', () {
        expect(
          () => ValidationService.validateRouteSearch('0'),
          throwsA(isA<ArgumentError>().having((e) => e.toString(), 'message', contains('Route number boundary violation'))),
        );
      });

      test('Route Number = -1', () {
        expect(
          () => ValidationService.validateRouteSearch('-1'),
          // Note: '-' is allowed as character, but '-1' parses to integer negative which is out of boundary.
          throwsA(isA<ArgumentError>().having((e) => e.toString(), 'message', contains('Route number boundary violation'))),
        );
      });
    });

    group('Negative Test Cases', () {
      test('Null route', () {
        expect(
          () => ValidationService.validateRouteSearch(null),
          throwsA(isA<ArgumentError>().having((e) => e.toString(), 'message', contains('Null route'))),
        );
      });

      test('Empty route', () {
        expect(
          () => ValidationService.validateRouteSearch('  '),
          throwsA(isA<ArgumentError>().having((e) => e.toString(), 'message', contains('Empty route'))),
        );
      });

      test('Special characters', () {
        final specialRoutes = ['10#', r'route$', '138!', '1-2%'];
        for (final route in specialRoutes) {
          expect(
            () => ValidationService.validateRouteSearch(route),
            throwsA(isA<ArgumentError>().having((e) => e.toString(), 'message', contains('Special characters'))),
          );
        }
      });
    });
  });

  group('3.3 Passenger Count Update', () {
    group('Equivalence Partitions', () {
      test('Valid: Passenger enters the bus', () {
        final nextCount = ValidationService.updatePassengerCount(
          currentCount: 15,
          action: 'enter',
          delta: 1,
        );
        expect(nextCount, equals(16));
      });

      test('Valid: Passenger exits the bus', () {
        final nextCount = ValidationService.updatePassengerCount(
          currentCount: 15,
          action: 'exit',
          delta: 1,
        );
        expect(nextCount, equals(14));
      });

      test('Invalid: Passenger exits when count is zero', () {
        expect(
          () => ValidationService.updatePassengerCount(
            currentCount: 0,
            action: 'exit',
            delta: 1,
          ),
          throwsA(isA<StateError>().having((e) => e.toString(), 'message', contains('Passenger exits when count is zero'))),
        );
      });

      test('Invalid: Passenger enters when the bus is full', () {
        expect(
          () => ValidationService.updatePassengerCount(
            currentCount: 60,
            action: 'enter',
            delta: 1,
          ),
          throwsA(isA<StateError>().having((e) => e.toString(), 'message', contains('Passenger enters when the bus is full'))),
        );
      });
    });

    group('Boundary Value Analysis (Bus Capacity = 60)', () {
      test('Current count = 0 (Enter 1)', () {
        final result = ValidationService.updatePassengerCount(
          currentCount: 0,
          action: 'enter',
          delta: 1,
        );
        expect(result, equals(1));
      });

      test('Current count = 0 (Exit 1 - invalid)', () {
        expect(
          () => ValidationService.updatePassengerCount(
            currentCount: 0,
            action: 'exit',
            delta: 1,
          ),
          throwsA(isA<StateError>()),
        );
      });

      test('Current count = 1 (Exit 1)', () {
        final result = ValidationService.updatePassengerCount(
          currentCount: 1,
          action: 'exit',
          delta: 1,
        );
        expect(result, equals(0));
      });

      test('Current count = 59 (Enter 1)', () {
        final result = ValidationService.updatePassengerCount(
          currentCount: 59,
          action: 'enter',
          delta: 1,
        );
        expect(result, equals(60));
      });

      test('Current count = 60 (Exit 1)', () {
        final result = ValidationService.updatePassengerCount(
          currentCount: 60,
          action: 'exit',
          delta: 1,
        );
        expect(result, equals(59));
      });

      test('Current count = 60 (Enter 1 - invalid)', () {
        expect(
          () => ValidationService.updatePassengerCount(
            currentCount: 60,
            action: 'enter',
            delta: 1,
          ),
          throwsA(isA<StateError>()),
        );
      });

      test('Current count = 61 (Invalid current count)', () {
        expect(
          () => ValidationService.updatePassengerCount(
            currentCount: 61,
            action: 'enter',
            delta: 1,
          ),
          throwsA(isA<ArgumentError>().having((e) => e.toString(), 'message', contains('Current count exceeds maximum capacity'))),
        );
      });
    });

    group('Negative Test Cases', () {
      test('Negative passenger count', () {
        expect(
          () => ValidationService.updatePassengerCount(
            currentCount: -5,
            action: 'enter',
            delta: 1,
          ),
          throwsA(isA<ArgumentError>().having((e) => e.toString(), 'message', contains('Negative passenger count'))),
        );
      });

      test('Invalid action value', () {
        expect(
          () => ValidationService.updatePassengerCount(
            currentCount: 20,
            action: 'jump',
            delta: 1,
          ),
          throwsA(isA<ArgumentError>().having((e) => e.toString(), 'message', contains('Invalid action value'))),
        );
      });

      test('Null input values', () {
        expect(
          () => ValidationService.updatePassengerCount(
            currentCount: null,
            action: 'enter',
            delta: 1,
          ),
          throwsA(isA<ArgumentError>().having((e) => e.toString(), 'message', contains('Null input values'))),
        );
        expect(
          () => ValidationService.updatePassengerCount(
            currentCount: 10,
            action: null,
            delta: 1,
          ),
          throwsA(isA<ArgumentError>().having((e) => e.toString(), 'message', contains('Null input values'))),
        );
        expect(
          () => ValidationService.updatePassengerCount(
            currentCount: 10,
            action: 'enter',
            delta: null,
          ),
          throwsA(isA<ArgumentError>().having((e) => e.toString(), 'message', contains('Null input values'))),
        );
      });
    });
  });

  group('3.4 Pickup Request', () {
    final List<Map<String, dynamic>> mockQueue = [
      {'passengerId': 101, 'busId': 'bus1'},
      {'passengerId': 102, 'busId': 'bus1'},
      {'passengerId': 103, 'busId': 'bus1'},
    ];

    group('Equivalence Partitions', () {
      test('Valid: Valid passenger ID and bus ID', () {
        final result = ValidationService.validatePickupRequest(
          passengerId: 104,
          busId: 'bus1',
          existingQueue: mockQueue,
        );
        expect(result, isTrue);
      });

      test('Invalid: Invalid passenger ID (<= 0)', () {
        expect(
          () => ValidationService.validatePickupRequest(
            passengerId: 0,
            busId: 'bus1',
            existingQueue: mockQueue,
          ),
          throwsA(isA<ArgumentError>().having((e) => e.toString(), 'message', contains('Invalid passenger'))),
        );
      });

      test('Invalid: Invalid bus ID (empty)', () {
        expect(
          () => ValidationService.validatePickupRequest(
            passengerId: 104,
            busId: '   ',
            existingQueue: mockQueue,
          ),
          throwsA(isA<ArgumentError>().having((e) => e.toString(), 'message', contains('Empty IDs'))),
        );
      });

      test('Invalid: Duplicate pickup request', () {
        expect(
          () => ValidationService.validatePickupRequest(
            passengerId: 101, // Already in mockQueue
            busId: 'bus1',
            existingQueue: mockQueue,
          ),
          throwsA(isA<StateError>().having((e) => e.toString(), 'message', contains('Duplicate pickup request'))),
        );
      });
    });

    group('Boundary Value Analysis', () {
      test('First pickup request (queue size = 0)', () {
        final result = ValidationService.validatePickupRequest(
          passengerId: 101,
          busId: 'bus1',
          existingQueue: [],
        );
        expect(result, isTrue);
      });

      test('Maximum request queue size (size = 4, capacity = 5)', () {
        final fullQueue = [
          {'passengerId': 201, 'busId': 'bus2'},
          {'passengerId': 202, 'busId': 'bus2'},
          {'passengerId': 203, 'busId': 'bus2'},
          {'passengerId': 204, 'busId': 'bus2'},
        ];
        final result = ValidationService.validatePickupRequest(
          passengerId: 205,
          busId: 'bus2',
          existingQueue: fullQueue,
          maxQueueSize: 5,
        );
        expect(result, isTrue);
      });

      test('Queue overflow (size = 5, capacity = 5)', () {
        final overflowQueue = [
          {'passengerId': 201, 'busId': 'bus2'},
          {'passengerId': 202, 'busId': 'bus2'},
          {'passengerId': 203, 'busId': 'bus2'},
          {'passengerId': 204, 'busId': 'bus2'},
          {'passengerId': 205, 'busId': 'bus2'},
        ];
        expect(
          () => ValidationService.validatePickupRequest(
            passengerId: 206,
            busId: 'bus2',
            existingQueue: overflowQueue,
            maxQueueSize: 5,
          ),
          throwsA(isA<StateError>().having((e) => e.toString(), 'message', contains('Queue overflow'))),
        );
      });
    });

    group('Negative Test Cases', () {
      test('Null passenger ID', () {
        expect(
          () => ValidationService.validatePickupRequest(
            passengerId: null,
            busId: 'bus1',
            existingQueue: mockQueue,
          ),
          throwsA(isA<ArgumentError>().having((e) => e.toString(), 'message', contains('Null IDs'))),
        );
      });

      test('Null bus ID', () {
        expect(
          () => ValidationService.validatePickupRequest(
            passengerId: 101,
            busId: null,
            existingQueue: mockQueue,
          ),
          throwsA(isA<ArgumentError>().having((e) => e.toString(), 'message', contains('Null IDs'))),
        );
      });

      test('Null queue', () {
        expect(
          () => ValidationService.validatePickupRequest(
            passengerId: 101,
            busId: 'bus1',
            existingQueue: null,
          ),
          throwsA(isA<ArgumentError>().having((e) => e.toString(), 'message', contains('Null IDs'))),
        );
      });

      test('Empty IDs', () {
        expect(
          () => ValidationService.validatePickupRequest(
            passengerId: 101,
            busId: '',
            existingQueue: mockQueue,
          ),
          throwsA(isA<ArgumentError>().having((e) => e.toString(), 'message', contains('Empty IDs'))),
        );
      });

      test('Duplicate submissions in queue', () {
        final queue = [
          {'passengerId': 101, 'busId': 'bus1'},
        ];
        expect(
          () => ValidationService.validatePickupRequest(
            passengerId: 101,
            busId: 'bus1',
            existingQueue: queue,
          ),
          throwsA(isA<StateError>().having((e) => e.toString(), 'message', contains('Duplicate pickup request'))),
        );
      });
    });
  });
}
