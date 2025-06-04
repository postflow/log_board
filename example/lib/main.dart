import 'package:flutter/material.dart';
import 'package:log_board/log_board.dart';

LogServer? logServer;

void main() async {
  logServer = LogServer().init(
    rootApp: () {
      WidgetsFlutterBinding.ensureInitialized();
      runApp(const MyApp());
    },
    port: 4040,
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
