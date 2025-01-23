# CrowdHandler Flutter

A Flutter package integrating [CrowdHandler](https://crowdhandler.com) for managing waiting room flows, request tracking, and performance metrics—all in a **plug-and-play** manner.

## Table of Contents

1. [Overview](#overview)
2. [Installation](#installation)
3. [Basic Usage](#basic-usage)
4. [Example App](#example-app)
5. [Advanced Usage](#advanced-usage)
   - [Dynamic URL Generation](#dynamic-url-generation)
   - [Time Tracking](#time-tracking)
   - [Minimal vs. Custom Waiting Room UI](#minimal-vs-custom-waiting-room-ui)
   - [Multi-Screen Approaches](#multi-screen-approaches)
6. [Contributing](#contributing)
7. [License](#license)

---

## Overview

https://www.crowdhandler.com/docs/80000183802-getting-started-with-crowdhandler

**CrowdHandler** provides waiting-room workflows for high-demand events or flash-sales. This Flutter package:

- Makes **POST/GET** requests to CrowdHandler’s `/v1/requests` and `/v1/responses` endpoints.
- Stores a user token in-memory automatically.
- Offers a **`WaitingRoomWebView`** widget that closes itself once the user is promoted.
- Provides a **`WaitingRoomPageRoute`** to show the waiting room.

---

## Installation

1. **Add** this package to your `pubspec.yaml`:

```
dependencies:
  crowdhandler_flutter: ^1.0.0
```

2. **Run** `flutter pub get`.

3. **Import** in your code:

```
import 'package:crowdhandler_flutter/crowdhandler_flutter.dart';
```

---

## Basic Usage

1. **Create a Session**:

```
final session = CrowdHandlerSession(
  // Found in CrowdHandler Control Panel -> Account -> API 
  xApiKey: 'YOUR_CROWDHANDLER_PUBLIC_API_KEY',
);
```

2. **POST or GET** with a CrowdHandler protected URL:

```
final result = await session.createOrFetch('https://mydomain.com/protected-eventID');
if (result.promoted == 0) {
  // show waiting room
} else {
  // user is promoted (1)
}
```

3. **Show Waiting Room** if `promoted == 0`:

```
Navigator.push(
  context,
  WaitingRoomPageRoute(
    slug: result.slug,
    session: session,
  ),
);
```

This **route** automatically builds a `Scaffold` with `WaitingRoomWebView`. When `"promoted":1` arrives, it closes itself.

---

## Example App

A **fully working** sample exists in your `example/` folder. To run it:

1. `cd crowdhandler_flutter/example`
2. `flutter pub get`
3. `flutter run`

That sample shows both **minimal** usage (using `WaitingRoomPageRoute`) and a **custom** approach (embedding `WaitingRoomWebView`) if you need more control.

---

## Advanced Usage

### Dynamic URL Generation

Often, you’ll build the CrowdHandler URL from your **app data**. For instance, if your event ID is `5305`:

```
final eventId = '5305';
final crowdUrl = 'https://mydomain.com/$eventId';
final result = await session.createOrFetch(crowdUrl);
```

`'https://mydomain.com'` should be replaced with the [domain](https://www.crowdhandler.com/docs/80000955960) configured in your CrowdHandler control panel. 

`'/5305'` should be replaced with the path you will be checking against the CrowdHandler API. If it is covered by your [room configuration](https://www.crowdhandler.com/docs/80000126037-adding-or-editing-a-waiting-room), the request will be considered for queueing. 
 

### Time Tracking

If the user is promoted, you can measure how long they waited:

```
_stopwatch.stop();
final durationMs = _stopwatch.elapsedMilliseconds;

await session.putResponseTime(
  responseID: result.responseID!,
  timeMs: durationMs,
  httpCode: 200, // default
);
```

This calls **PUT** `/responses/{responseID}`, letting CrowdHandler analyze request fulfillment performance.

### Minimal vs. Custom Waiting Room UI

- **Minimal** (built-in route):

  ```
  Navigator.push(
    context,
    WaitingRoomPageRoute(
      slug: result.slug,
      session: session,
    ),
  );
  ```

- **Custom** (embed `WaitingRoomWebView` directly):
  ```
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text('My Custom Room')),
        body: WaitingRoomWebView(
          slug: result.slug,
          session: session,
          onPromoted: (token) {
            // store token or show a message
          },
        ),
      ),
    ),
  );
  ```

### Multi-Screen Approaches

If you need to check CrowdHandler on **multiple pages**:

1. **Per-Screen `initState()`**

   ```
   @override
   void initState() {
     super.initState();
     _checkCrowdHandler();
   }
   ```

2. **`RouteObserver`**

   ```
   MaterialApp(
     navigatorObservers: [
       CrowdHandlerRouteObserver(session),
     ],
   );
   ```

3. **`BaseCrowdHandlerPage`**

   ```
   abstract class BaseCrowdHandlerPage extends StatefulWidget {
     final String slug;
     ...
   }

   abstract class BaseCrowdHandlerState<T extends BaseCrowdHandlerPage> extends State<T> {
     @override
     void initState() {
       super.initState();
       session.createOrFetch('https://mydomain.com/${widget.slug}');
     }
   }
   ```
