import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint, PlatformDispatcher;
import 'package:http/http.dart' as http;
import 'crowdhandler_result.dart';
import 'crowdhandler_exception.dart';

/// A session-based interface to CrowdHandler with:
/// - timeouts & fallback so the app never breaks,
/// - a static user agent = "Flutter App",
/// - region-based language detection from device locale if available (e.g. "en-US"),
/// - no constructor changes => backward compatibility.
class CrowdHandlerSession {
  final String xApiKey;
  final String baseUrl;
  String? token;

  CrowdHandlerSession({
    required this.xApiKey,
    this.baseUrl = 'https://api.crowdhandler.com/v1',
    this.token,
  });

  /// Infers `agent = "Flutter App"`,
  /// and `lang` as languageCode-countryCode if possible (e.g. "en-US"), 
  /// else just languageCode (e.g. "en"), fallback "en" if no locale found.
  Map<String, String> _inferAgentLang() {
    const String detectedAgent = 'Flutter App';
    String detectedLang = 'en'; // fallback

    try {
      final locales = PlatformDispatcher.instance.locales;
      if (locales.isNotEmpty) {
        final first = locales.first;
        final language = first.languageCode;    // e.g. "en"
        final country = first.countryCode;      // e.g. "US"
        if (country != null && country.isNotEmpty) {
          detectedLang = '$language-$country';  // "en-US"
        } else {
          detectedLang = language;              // "en"
        }
      }
    } catch (e) {
      debugPrint('Error detecting locale: $e');
      // fallback => "en"
    }

    return {
      'agent': detectedAgent,
      'lang': detectedLang,
    };
  }

  /// POST /requests => if no token, create new waiting room request.
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
      'agent': al['agent'],   // "Flutter App"
      'lang': al['lang'],     // e.g. "en-US"
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
      'agent': al['agent'], // "Flutter App"
      'lang': al['lang'],   // e.g. "en-US"
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
      'agent': al['agent'], // "Flutter App"
      'lang': al['lang'],   // e.g. "en-US"
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
