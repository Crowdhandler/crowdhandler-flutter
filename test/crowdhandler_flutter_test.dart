// test/crowdhandler_flutter_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:crowdhandler_flutter/crowdhandler_flutter.dart';

void main() {
  group('CrowdHandlerResult', () {
    test('fromJson parses promoted/token/slug/responseID correctly', () {
      final json = {
        "promoted": 1,
        "token": "tokXYZ123",
        "slug": "herb-girls",
        "responseID": "b6850d433106af0fc1fb4dec6f312116"
      };

      final result = CrowdHandlerResult.fromJson(json);

      expect(result.promoted, 1);
      expect(result.token, "tokXYZ123");
      expect(result.slug, "herb-girls");
      expect(result.responseID, "b6850d433106af0fc1fb4dec6f312116");
    });

    test('fromJson handles missing optional fields', () {
      final json = {
        "promoted": 0,
      };

      final result = CrowdHandlerResult.fromJson(json);

      expect(result.promoted, 0);
      expect(result.token, isNull);
      expect(result.slug, isNull);
      expect(result.responseID, isNull);
    });
  });
}
