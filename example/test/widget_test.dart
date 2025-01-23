// example/test/widget_test.dart

import 'package:flutter_test/flutter_test.dart';

// Import your example app entry point
import 'package:crowdhandler_flutter_example/main.dart';

void main() {
  testWidgets('CrowdHandlerExampleApp renders and has AppBar title',
      (WidgetTester tester) async {
    // 1. Build our app and trigger a frame.
    await tester.pumpWidget(const CrowdHandlerExampleApp());

    // 2. Verify app bar title is present
    expect(find.text('CrowdHandler Example'), findsOneWidget);

    // 3. Verify something else if desired (like a button, text, etc.)
    // e.g. expect(find.text('Create Request'), findsOneWidget);
  });
}
