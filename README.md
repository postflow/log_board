# LogBoard

**LogBoard** is especially useful for QA specialists who may not have a full Flutter development environment installed or access to Flutter DevTools. Since the logs are served over HTTP and viewable in any browser, QA testers can observe all logs — including print, debugPrint, uncaught exceptions, and network-related outputs — without needing to interact with the app UI or navigate to a separate in-app debug screen.

This makes it easy to:
- Test apps on real devices without using Android Studio or VS Code
- Track logs in real time from a desktop browser
- Observe network requests and internal app behavior
- Share logs with developers without needing screenshots or recordings
---
## 🚀 Features
- Captures everything printed to the Flutter console — including print(), debugPrint(), and uncaught errors
- Allows you to view logs from your Flutter app directly in a browser window on another device (e.g. desktop, laptop, or tablet)
- Provides a built-in HTML log viewer accessible via http://<device-ip>:<port>
- Ideal for debugging on physical devices without needing to connect via IDE or cables
---

## 📦 Installation

In your `pubspec.yaml`:

```yaml
dependencies:
  log_board:
    git:
      url: https://github.com/postflow/log_board
```

## 🛠️ Quick Start

```dart
import 'package:flutter/material.dart';
import 'package:log_board/log_board.dart';

LogServer? logServer;

void main() async {
  logServer = LogServer().init(
    rootApp: () {
      WidgetsFlutterBinding.ensureInitialized();
      runApp(const MyApp());
    },
    logTransformer: (log) {
      final timestamp = DateTime.now().toIso8601String();
      return '[$timestamp] $log';
    },
    flutterOnError: (FlutterErrorDetails details) {
      // final error = details.exceptionAsString();
      // final stack = details.stack?.toString() ?? 'No stack trace';
      //
      // final timestamp = DateTime.now().toIso8601String();
      // final logMessage = '[$timestamp] FLUTTER ERROR:\n$error\n$stack';
      // sendLogToServer(logMessage);
    } ,
    ipPort: 4040,
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isRunning = false;
  int? _port;
  String? _ipAddress;

  _listener(ServerStatus serverStatus) {
    setState(() {
      _isRunning = serverStatus.isRunning;
      if (_isRunning) {
        _port = serverStatus.port;
        _ipAddress = serverStatus.address?.address;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    logServer?.subscribeOnServerStatus(_listener);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Log Server Example')),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: Text(_isRunning
                  ? 'Log server is running: http://$_ipAddress:$_port'
                  : 'Log server not running')
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  logServer?.startServer();
                },
                child: const Text('start server'),
              ),
              ElevatedButton(
                onPressed: () {
                  logServer?.stopServer();
                },
                child: const Text('stop server'),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  print('print to console');
                },
                child: const Text('print to console'),
              ),
              ElevatedButton(
                onPressed: () {
                  debugPrint('debugPrint to console');
                },
                child: const Text('debugPrint to console'),
              ),
              ElevatedButton(
                onPressed: () {
                  throw Exception('Test error');
                },
                child: const Text('throw Exception'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    logServer?.unSubscribe(_listener);
    super.dispose();
  }
}
```
### ▶️ OR:
#### Clone the Repository
```
git clone https://github.com/postflow/log_board.git
cd log_board
```

#### Get Dependencies
```
flutter pub get
```
#### Run the Example
```
flutter run --target=example/lib/main.dart
```
#### Open the Viewer
http://device-ip:4040

(e.g. http://192.168.1.10:4040 on the same Wi-Fi network)