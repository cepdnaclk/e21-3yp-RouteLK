// run_tests.dart
import 'lib/services/validation_service.dart';

void main() async {
  print('========================================');
  print('      RouteLK Validation Demo Run       ');
  print('========================================\n');

  // Test 1: Email Login validation
  print('--- Testing Email Validation ---');
  try {
    ValidationService.validateLoginEmail('passenger@routelk.lk');
    print('[PASS] "passenger@routelk.lk" is valid');
  } catch (e) {
    print('[FAIL] "passenger@routelk.lk" failed: $e');
  }

  try {
    ValidationService.validateLoginEmail("admin@example.com' OR '1'='1");
    print('[FAIL] SQL Injection test failed to throw error');
  } catch (e) {
    print('[PASS] SQL Injection detected correctly: $e');
  }

  // Test 2: Password Login validation
  print('\n--- Testing Password Validation ---');
  try {
    ValidationService.validateLoginPassword('ValidPass123');
    print('[PASS] "ValidPass123" is valid');
  } catch (e) {
    print('[FAIL] "ValidPass123" failed: $e');
  }

  try {
    ValidationService.validateLoginPassword('short');
    print('[FAIL] "short" failed to throw error');
  } catch (e) {
    print('[PASS] Short password boundary caught: $e');
  }

  // Test 3: Route search validation
  print('\n--- Testing Route Search ---');
  try {
    ValidationService.validateRouteSearch('138');
    print('[PASS] Route "138" is valid');
  } catch (e) {
    print('[FAIL] Route "138" failed: $e');
  }

  try {
    ValidationService.validateRouteSearch('-5');
    print('[FAIL] Route "-5" failed to throw error');
  } catch (e) {
    print('[PASS] Invalid route boundary caught: $e');
  }

  // Test 4: Passenger Count Update
  print('\n--- Testing Passenger Count Update ---');
  try {
    final updated = ValidationService.updatePassengerCount(
      currentCount: 50,
      action: 'enter',
      delta: 5,
    );
    print('[PASS] 5 passengers entered. Count updated from 50 to $updated');
  } catch (e) {
    print('[FAIL] Passenger enter failed: $e');
  }

  try {
    ValidationService.updatePassengerCount(
      currentCount: 60,
      action: 'enter',
      delta: 1,
    );
    print('[FAIL] Over-capacity allowed');
  } catch (e) {
    print('[PASS] Capacity overflow caught: $e');
  }

  // Test 5: Pickup Request validation
  print('\n--- Testing Pickup Request ---');
  try {
    ValidationService.validatePickupRequest(
      passengerId: 104,
      busId: 'bus1',
      existingQueue: [
        {'passengerId': 101, 'busId': 'bus1'},
      ],
    );
    print('[PASS] Valid pickup request approved');
  } catch (e) {
    print('[FAIL] Valid pickup request failed: $e');
  }

  try {
    ValidationService.validatePickupRequest(
      passengerId: 101,
      busId: 'bus1',
      existingQueue: [
        {'passengerId': 101, 'busId': 'bus1'},
      ],
    );
    print('[FAIL] Duplicate pickup request allowed');
  } catch (e) {
    print('[PASS] Duplicate pickup request caught: $e');
  }

  print('\n========================================');
  print('           Demo Run Complete            ');
  print('========================================');
}
