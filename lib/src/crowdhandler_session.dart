import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'crowdhandler_result.dart';
import 'crowdhandler_exception.dart';

/// A session-based interface to CrowdHandler. 
///
/// Now with basic timeout & failure handling so the app remains functional even if the call fails.
class CrowdHandlerSession {
  final String xApiKey;
  final String baseUrl;
  String? token;

  CrowdHandlerSession({
    required this.xApiKey,
    this.baseUrl = 'https://api.crowdhandler.com/v1', 
    this.token,
  });

  /// POST /requests
  /// If there's no token, creates a new waiting room request.
  /// In case of timeout or any other failure, returns a fallback promoted=1 result.
  Future<CrowdHandlerResult> createRequest(String targetUrl) async {
    final endpoint = Uri.parse('$baseUrl/requests');
    final headers = {
      'x-api-key': xApiKey,
      'Content-Type': 'application/json',
    };
    final body = jsonEncode({'url': targetUrl});

    try {
      // Apply a timeout of 10 seconds (adjust as needed).
      final response = await http
          .post(endpoint, headers: headers, body: body)
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
      // Return a fallback => user is considered "promoted"
      return CrowdHandlerResult(promoted: 1);
    } catch (e, stack) {
      debugPrint('CrowdHandler createRequest FAILED: $e\n$stack');
      // Return fallback => user is "promoted"
      return CrowdHandlerResult(promoted: 1);
    }
  }

  /// GET /requests/{token}?url=<targetUrl>
  /// If we have a token, fetch the updated waiting room status.
  /// In case of errors, fallback to promoted=1.
  Future<CrowdHandlerResult> getRequest(String targetUrl) async {
    if (token == null) {
      debugPrint('CrowdHandler getRequest called without a token—returning fallback.');
      return CrowdHandlerResult(promoted: 1);
    }

    final endpoint = Uri.parse('$baseUrl/requests/$token?url=$targetUrl');
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

  /// Convenience method that decides whether to do POST or GET.
  /// If token is null => createRequest, else getRequest.
  Future<CrowdHandlerResult> createOrFetch(String targetUrl) async {
    if (token == null) {
      return createRequest(targetUrl);
    } else {
      return getRequest(targetUrl);
    }
  }

  /// PUT /responses/{responseID}
  /// In case of error/timeout, we log the issue but do not crash the app.
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
    final body = jsonEncode({
      'time': timeMs,
      'httpCode': httpCode,
    });

    try {
      final response = await http
          .put(endpoint, headers: headers, body: body)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        debugPrint('Time spent updated successfully: ${response.body}');
      } else {
        throw CrowdHandlerException(
          'PUT /responses/$responseID failed with status: ${response.statusCode}',
          response.body,
        );
      }
    } on TimeoutException catch (e, stack) {
      debugPrint('CrowdHandler putResponseTime TIMED OUT: $e\n$stack');
      // Not returning anything => just logging
    } catch (e, stack) {
      debugPrint('CrowdHandler putResponseTime FAILED: $e\n$stack');
      // Not throwing further => app continues
    }
  }

  /// Called by the waiting room WebView if a new token arrives from JavaScript.
  /// The integrator’s app typically doesn't need to do anything else.
  void updateToken(String newToken) {
    token = newToken;
  }
}
