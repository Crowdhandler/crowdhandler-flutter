import 'package:flutter/material.dart';
// Import your package entry
import 'package:crowdhandler_flutter/crowdhandler_flutter.dart';

/// This example demonstrates how to integrate CrowdHandler in a simple Flutter app.
/// 
/// 1) We create a [CrowdHandlerSession].
/// 2) We call [session.createOrFetch(...)] with a URL that represents the
///    domain/room you configured in CrowdHandler's backend.
/// 3) If the user is not promoted (promoted == 0), we push a waiting room route.
/// 
/// See also the commented sections below (Approaches A/B/C) for more advanced
/// multi-screen usage patterns.
void main() {
  runApp(const CrowdHandlerExampleApp());
}

class CrowdHandlerExampleApp extends StatelessWidget {
  const CrowdHandlerExampleApp({super.key});

  @override 
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CrowdHandler Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
      ),

      // If you want to try the RouteObserver approach (Approach B), 
      // uncomment the 'navigatorObservers' line below, then see the 
      // commented code in "APPROACH B" below.
/*
      navigatorObservers: [
        MyCrowdHandlerRouteObserver(
          CrowdHandlerSession(xApiKey: 'YOUR_API_KEY'),
        )
      ],
*/

      // By default, we go to a single "Home" screen that triggers CrowdHandler
      home: const CrowdHandlerHomePage(),
    );
  }
}

/// A simple home page demonstrating how to:
///   1) Create a [CrowdHandlerSession].
///   2) Call [session.createOrFetch(...)] with a typical CrowdHandler URL:
///      e.g., 'https://YOUR_DOMAIN.com/path-to-protected-event'.
///   3) If user is not promoted, show the waiting room route.
class CrowdHandlerHomePage extends StatefulWidget {
  const CrowdHandlerHomePage({super.key});

  @override
  State<CrowdHandlerHomePage> createState() => _CrowdHandlerHomePageState();
}

class _CrowdHandlerHomePageState extends State<CrowdHandlerHomePage> {
  // 1) Create a session-based interface with your xApiKey
  final session = CrowdHandlerSession(
    // Insert your real CrowdHandler API key here.
    // Found in CrowdHandler Control Panel -> Account -> API 
    xApiKey: 'YOUR_PUBLIC_API_KEY',
  );

  CrowdHandlerResult? latestResult;
  bool isLoading = false;
  String errorMessage = '';

  /// Example function that calls [session.createOrFetch(...)] with a
  /// hard-coded URL: 'https://example.com/protected-event-id'.
  /// 
  /// In a real app, you'd dynamically build your URL based on the event or
  /// screen context, e.g. `https://mydomain.com/$myEventID`.
  Future<void> _onCreateOrFetch() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });
    try {
      // 2) Attempt to create or fetch a request.
      // Replace 'https://example.com/protected-event-id' with your 
      // own domain & protected event ID, e.g. 'https://mydomain.com/event123'.
      // The domain should match the one that you configured in the CrowdHandler control panel.
      // The event ID should be protected by your CrowdHandler room configuration.
      final result = await session.createOrFetch('https://example.com/protected-event-id');
      setState(() => latestResult = result);

      // 3) If promoted == 0, user needs the waiting room. 
      //    We'll show the minimal approach by default:
      if (result.promoted == 0 && mounted) {
        Navigator.push(
          context,
          WaitingRoomPageRoute(
            // For typical usage, pass result.slug (or your own slug).
            slug: result.slug ?? 'hardcoded-backup-slug-here',
            session: session,
            onPromoted: (newToken) {
              // Optionally do something if we get a new token
              if (newToken != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Promoted! new token: $newToken')),
                );
              }
            },
            pageTitle: 'Waiting Room', // optional title
          ),
        );

        // -------------
        // ALTERNATIVE: custom UI approach with a direct [WaitingRoomWebView] 
        // instead of the built-in route:
        // -------------
        /*
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => Scaffold(
              appBar: AppBar(title: const Text('Custom Room')),
              body: WaitingRoomWebView(
                slug: result.slug ?? 'hardcoded-backup-slug-here',
                session: session,
                onPromoted: (newToken) {
                  if (newToken != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Custom approach, new token: $newToken')),
                    );
                  }
                },
              ),
            ),
          ),
        );
        */
      }
      // If promoted == 1, user is already in. You can do next steps here.

    } catch (e) {
      setState(() => errorMessage = '$e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final resultText = latestResult == null ? 'None' : latestResult.toString();

    return Scaffold(
      appBar: AppBar(
        title: const Text('CrowdHandler Demo'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (isLoading)
              const LinearProgressIndicator(),

            ElevatedButton(
              onPressed: _onCreateOrFetch,
              child: const Text('Create or Fetch Request'),
            ),

            const SizedBox(height: 20),
            Text('Result: $resultText'),

            if (errorMessage.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text('Error: $errorMessage', style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
    );
  }
}

/* ---------------------------------------------------------------------------
 APPROACH A: "Per-Screen initState"
 
 If you have multiple screens, you can call CrowdHandler in each screen's 
 initState, using a dynamic URL. For example, if your app shows 
 "EventDetailPage" for event ID "5305," you'd build a URL like:
 "https://mydomain.com/5305" or "https://test.crowdhandler.com/5305"

class MyScreen extends StatefulWidget {
  const MyScreen({super.key, required this.eventId});
  final String eventId;

  @override
  State<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends State<MyScreen> {
  @override
  void initState() {
    super.initState();
    _checkCrowdHandler();
  }

  Future<void> _checkCrowdHandler() async {
    final session = CrowdHandlerSession(xApiKey: 'YOUR_API_KEY');

    // Construct your CrowdHandler URL from eventId:
    // e.g. "https://mydomain.com/${widget.eventId}"
    final result = await session.createOrFetch('https://mydomain.com/${widget.eventId}');
    
    // If user not promoted => show waiting room route:
    if (result.promoted == 0 && mounted) {
      Navigator.push(
        context,
        WaitingRoomPageRoute(slug: result.slug ?? widget.eventId, session: session),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Hello from MyScreen, checks CrowdHandler in initState')),
    );
  }
}
--------------------------------------------------------------------------- */

/* ---------------------------------------------------------------------------
 APPROACH B: RouteObserver 
 You can watch route transitions with a "CrowdHandlerRouteObserver" 
 that calls session.createOrFetch when a route is pushed.
 
class CrowdHandlerRouteObserver extends RouteObserver<PageRoute<dynamic>> {
  final CrowdHandlerSession session;

  CrowdHandlerRouteObserver(this.session);

  @override
  void didPush(Route route, Route? previousRoute) {
    super.didPush(route, previousRoute);

    // For example, if route.settings.name == '/event/5305',
    // build your URL "https://mydomain.com/5305" and check CrowdHandler:
    if (route.settings.name != null) {
      final slug = route.settings.name!.replaceAll('/event/', '');
      _checkCrowdHandler(slug);
    }
  }

  Future<void> _checkCrowdHandler(String slug) async {
    final result = await session.createOrFetch('https://mydomain.com/$slug');
    if (result.promoted == 0) {
      // Show waiting room
    }
  }
}

// Then in MaterialApp:
MaterialApp(
  navigatorObservers: [
    CrowdHandlerRouteObserver(CrowdHandlerSession(xApiKey: 'YOUR_API_KEY')),
  ],
  // ...
);
--------------------------------------------------------------------------- */

/* ---------------------------------------------------------------------------
 APPROACH C: BaseCrowdHandlerPage 
 For advanced devs who want a base class that auto-checks CrowdHandler 
 in initState for every page that extends it.

abstract class BaseCrowdHandlerPage extends StatefulWidget {
  final String slug;
  const BaseCrowdHandlerPage({Key? key, required this.slug}) : super(key: key);
}

abstract class BaseCrowdHandlerState<T extends BaseCrowdHandlerPage> extends State<T> {
  @override
  void initState() {
    super.initState();
    _checkCrowd(widget.slug);
  }

  Future<void> _checkCrowd(String slug) async {
    final session = CrowdHandlerSession(xApiKey: 'YOUR_API_KEY');
    final result = await session.createOrFetch('https://mydomain.com/$slug');
    if (result.promoted == 0 && mounted) {
      Navigator.push(
        context,
        WaitingRoomPageRoute(slug: slug, session: session),
      );
    }
  }
}

// Then your page extends BaseCrowdHandlerPage:
class MyFancyPage extends BaseCrowdHandlerPage {
  const MyFancyPage({super.key, required super.slug});

  @override
  BaseCrowdHandlerState<BaseCrowdHandlerPage> createState() => _MyFancyPageState();
}

class _MyFancyPageState extends BaseCrowdHandlerState<MyFancyPage> {
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Fancy Page with auto-check')));
  }
}
--------------------------------------------------------------------------- */
