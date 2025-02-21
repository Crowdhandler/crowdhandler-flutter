import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint, PlatformDispatcher;
import 'package:http/http.dart' as http;

// Make sure you add fk_user_agent to your pubspec.yaml:
// dependencies:
//   fk_user_agent: ^1.0.1 (or latest)
// Then import it:
import 'package:fk_user_agent/fk_user_agent.dart';

import 'crowdhandler_result.dart';
import 'crowdhandler_exception.dart';

/// A session-based interface to CrowdHandler, with:
///  - timeouts & fallback so the app never breaks,
///  - automatic user agent inference via `fk_user_agent`,
///  - automatic language detection from device locale,
///  - no constructor changes => backward compatibility.
class CrowdHandlerSession {
  final String xApiKey;
  final String baseUrl;
  String? token;

  CrowdHandlerSession({
    required this.xApiKey,
    this.baseUrl = 'https://api.crowdhandler.com/v1',
    this.token,
  });

  /// --------------- INIT ---------------
  /// If you want to use fk_user_agent's detection, you should call:
  ///   await FkUserAgent.init();
  /// at app startup, or before making requests the first time.
  ///
  /// If not called, fk_user_agent will attempt to init lazily,
  /// but it's recommended to do so once in main(), for example:
  ///
  /// ```dart
  /// void main() async {
  ///   WidgetsFlutterBinding.ensureInitialized();
  ///   await FkUserAgent.init();
  ///   runApp(MyApp());
  /// }
  /// ```
  /// This ensures FkUserAgent.userAgent is populated.
  /// ------------------------------------

  /// Infers `agent` using `fk_user_agent`, and `lang` from device locale.
  /// Falls back to "MyFlutterApp" / "en" if anything fails.
  Map<String, String> _inferAgentLang() {
    String detectedAgent = 'MyFlutterApp';
    String detectedLang = 'en';

    try {
      // 1) Attempt to read the user agent from FkUserAgent
      // If not initialized, it tries to init automatically but may not always work perfectly.
      final userAgent = FkUserAgent.userAgent; 
      // If null or empty, we keep fallback
      if (userAgent != null && userAgent.isNotEmpty) {
        detectedAgent = userAgent;
      }
    } catch (e) {
      debugPrint('fk_user_agent detection failed: $e');
    }

    try {
      // 2) Attempt to read device locale
      final locales = PlatformDispatcher.instance.locales;
      if (locales.isNotEmpty) {
        detectedLang = locales.first.languageCode; // e.g. 'en'
      }
    } catch (e) {
      debugPrint('Error detecting language: $e');
    }

    return {
      'agent': detectedAgent,
      'lang': detectedLang,
    };
  }

  /// POST /requests
  /// On error => fallback => promoted=1
  Future<CrowdHandlerResult> createRequest(String targetUrl) async {
    final endpoint = Uri.parse('$baseUrl/requests');
    final headers = {
      'x-api-key': xApiKey,
      'Content-Type': 'application/json',
    };

    final al = _inferAgentLang();
    final bodyMap = {
      'url': targetUrl,
      'agent': al['agent'],
      'lang': al['lang'],
    };
    final bodyJson = jsonEncode(bodyMap);

    try {
      final response = await http
          .post(endpoint, headers: headers, body: bodyJson)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final result = CrowdHandlerResult.fromJson(data['result']);
        token = result.token;
        return result;
      } else {
        throw CrowdHandlerException(
          'POST /requests failed with status: ${response.statusCode}',
          response.body,
        );
      }
    } on TimeoutException catch (e, stack) {
      debugPrint('CrowdHandler createRequest TIMED OUT: $e\n$stack');
      return CrowdHandlerResult(promoted: 1);
    } catch (e, stack) {
      debugPrint('CrowdHandler createRequest FAILED: $e\n$stack');
      return CrowdHandlerResult(promoted: 1);
    }
  }

  /// GET /requests/{token}?url=...&agent=...&lang=...
  /// If token is null => fallback => user in
  Future<CrowdHandlerResult> getRequest(String targetUrl) async {
    if (token == null) {
      debugPrint('getRequest called without token => fallback => promoted=1');
      return CrowdHandlerResult(promoted: 1);
    }

    final al = _inferAgentLang();
    final queryMap = {
      'url': targetUrl,
      'agent': al['agent'],
      'lang': al['lang'],
    };
    final query = Uri(queryParameters: queryMap).query;
    final endpoint = Uri.parse('$baseUrl/requests/$token?$query');

    final headers = {
      'x-api-key': xApiKey,
      'Content-Type': 'application/json',
    };

    try {
      final response = await http
          .get(endpoint, headers: headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final result = CrowdHandlerResult.fromJson(data['result']);
        token = result.token;
        return result;
      } else {
        throw CrowdHandlerException(
          'GET /requests/$token failed with status: ${response.statusCode}',
          response.body,
        );
      }
    } on TimeoutException catch (e, stack) {
      debugPrint('CrowdHandler getRequest TIMED OUT: $e\n$stack');
      return CrowdHandlerResult(promoted: 1);
    } catch (e, stack) {
      debugPrint('CrowdHandler getRequest FAILED: $e\n$stack');
      return CrowdHandlerResult(promoted: 1);
    }
  }

  /// Decide if we do POST or GET
  Future<CrowdHandlerResult> createOrFetch(String targetUrl) async {
    if (token == null) {
      return createRequest(targetUrl);
    } else {
      return getRequest(targetUrl);
    }
  }

  /// PUT /responses/{responseID} => includes agent/lang
  Future<void> putResponseTime({
    required String responseID,
    required int timeMs,
    int httpCode = 200,
  }) async {
    final endpoint = Uri.parse('$baseUrl/responses/$responseID');
    final headers = {
      'x-api-key': xApiKey,
      'Content-Type': 'application/json',
    };

    final al = _inferAgentLang();
    final bodyMap = {
      'time': timeMs,
      'httpCode': httpCode,
      'agent': al['agent'],
      'lang': al['lang'],
    };
    final bodyJson = jsonEncode(bodyMap);

    try {
      final response = await http
          .put(endpoint, headers: headers, body: bodyJson)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        debugPrint('Time spent updated: ${response.body}');
      } else {
        throw CrowdHandlerException(
          'PUT /responses/$responseID failed with status: ${response.statusCode}',
          response.body,
        );
      }
    } on TimeoutException catch (e, stack) {
      debugPrint('CrowdHandler putResponseTime TIMED OUT: $e\n$stack');
    } catch (e, stack) {
      debugPrint('CrowdHandler putResponseTime FAILED: $e\n$stack');
    }
  }

  /// If the waiting room WebView returns a new token, store it.
  void updateToken(String newToken) {
    token = newToken;
  }
}
