import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'crowdhandler_session.dart';

/// A plug-and-play widget for displaying CrowdHandler’s waiting room.
///
/// If the JS says `"promoted":1`, we automatically:
///   - Update [session].token if a new token is provided
///   - Pop this route (close the WebView).
class WaitingRoomWebView extends StatefulWidget {
  final String slug;
  final CrowdHandlerSession session;

  /// Optional callback if you want to do something after the user is promoted,
  /// e.g. store the token in your own app state, show a toast, etc.
  final void Function(String? newToken)? onPromoted;

  const WaitingRoomWebView({
    Key? key,
    required this.slug,
    required this.session,
    this.onPromoted,
  }) : super(key: key);

  @override
  State<WaitingRoomWebView> createState() => _WaitingRoomWebViewState();
}

class _WaitingRoomWebViewState extends State<WaitingRoomWebView> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();

    // Build the waiting room URL with the current token (if any)
    final url = 'https://wait.crowdhandler.com/'
        '${widget.slug}?ch-id=${widget.session.token ?? ''}&ch_mode=flutter';

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'CHMessage',
        onMessageReceived: (JavaScriptMessage message) {
          if (!mounted) return;
          final msg = message.message;
          debugPrint('CrowdHandler JS message: $msg');

          try {
            final data = jsonDecode(msg) as Map<String, dynamic>;
            final promoted = data['promoted'] as int?;
            final newToken = data['token'] as String?;

            if (promoted == 1) {
              // If we get a new token from JS, store it in the session
              if (newToken != null) {
                widget.session.updateToken(newToken);
              }
              // Optionally notify integrator
              widget.onPromoted?.call(newToken);

              // Close the WebView
              Navigator.of(context).pop();
            }
          } catch (e) {
            debugPrint('Error parsing JS message: $e');
          }
        },
      )
      ..loadRequest(Uri.parse(url));
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _controller);
  }
}

/// A **fully built route** (extends [MaterialPageRoute]) that displays a
/// [WaitingRoomWebView] inside a [Scaffold] with a default [AppBar].
///
/// Usage:
/// ```dart
/// Navigator.push(
///   context,
///   WaitingRoomPageRoute(
///     slug: 'herb-girls',
///     session: mySession,
///     onPromoted: (newToken) { ... },
///   ),
/// );
/// ```
class WaitingRoomPageRoute extends MaterialPageRoute<void> {
  WaitingRoomPageRoute({
    required String slug,
    required CrowdHandlerSession session,
    void Function(String? newToken)? onPromoted,
    String pageTitle = 'Waiting Room',
  }) : super(
          builder: (context) {
            return Scaffold(
              appBar: AppBar(
                title: Text(pageTitle),
              ),
              body: WaitingRoomWebView(
                slug: slug,
                session: session,
                onPromoted: onPromoted,
              ),
            );
          },
        );
}
