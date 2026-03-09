import 'package:flutter_test/flutter_test.dart';
import 'package:bus_tracker/main.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const BusTrackerApp());
    expect(find.byType(BusTrackerApp), findsOneWidget);
  });
}
