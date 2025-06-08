import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const int defaultServerIpPort = 4040;
/// Represents the current status of the log server.
class ServerStatus {
  /// Indicates whether the server is running.
  final bool isRunning;

  /// The IP address the server is bound to, if any.
  final InternetAddress? address;

  /// The port the server is listening on, if any.
  final int? port;

  ServerStatus(this.isRunning, this.address, this.port);
}

/// A singleton class that captures Flutter logs and errors and sends them to WebSocket clients.
/// It can also serve an HTML log viewer over HTTP.
class LogServer {
  static final LogServer _instance = LogServer._internal();
  final List<WebSocket> _clients = [];
  final List<Function(ServerStatus)> _subscribers = [];
  HttpServer? _server;
  bool _isRunning = false;
  String Function(String dd)? _logTransformer;
  int _ipPort = defaultServerIpPort;
  factory LogServer() => _instance;
  LogServer._internal();

  /// Initializes the log server and sets up error capturing and log redirection.
  ///
  /// - [rootApp]: the main entry point of your Flutter app, typically the `runApp()` call.
  /// - [flutterOnError]: optional callback for handling Flutter framework errors.
  /// - [logTransformer]: optional function to transform log messages before sending them to WebSocket clients.
  /// - [ipPort]: optional custom port number for the HTTP/WebSocket server (defaults to [defaultServerIpPort]).
  ///
  /// This method wraps the app in a [runZonedGuarded] block to capture uncaught errors and override `debugPrint`.
  ///
  /// Returns the initialized [LogServer] singleton instance.
  LogServer init({
    required Function() rootApp,
    Function(FlutterErrorDetails details)? flutterOnError,
    String Function(String)? logTransformer,
    int? ipPort}) {
      _ipPort = ipPort ?? defaultServerIpPort;
      _logTransformer = logTransformer;

      runZonedGuarded(
            () {
          FlutterError.onError = (FlutterErrorDetails details) {
            if (flutterOnError != null) {
              flutterOnError.call(details);
            }
            Zone.current.handleUncaughtError(details.exception, details.stack ?? StackTrace.current);
          };

          debugPrint = (String? message, {int? wrapWidth}) {
            if (message != null) {
              Zone.current.print(message);
            }
          };

          rootApp();
        },
            (error, stack) {
          Zone.current.print('$error\n$stack');
          _broadcast('$error\n$stack');
        },
        zoneSpecification: ZoneSpecification(
          print: (Zone self, ZoneDelegate parent, Zone zone, String message) {
            parent.print(zone, message);
            _broadcast(message);
          },
        ),
      );
      return this;
  }

  /// Subscribes a callback to listen for server status changes.
  ///
  /// The callback receives a [ServerStatus] object whenever the server starts or stops.
  void subscribeOnServerStatus(Function(ServerStatus) onStatusChange) {
    _subscribers.add(onStatusChange);
  }

  /// Unsubscribes a previously added server status callback.
  void unSubscribe(Function(ServerStatus) onStatusChange) {
    _subscribers.remove(onStatusChange);
  }

  void _notifySubscribers() {
    for (final subscriber in _subscribers) {
      if (_isRunning) {
        subscriber.call(ServerStatus(true, _server?.address, _server?.port));
      } else {
        subscriber.call(ServerStatus(false, _server?.address, _server?.port));
      }
    }
  }

  /// Starts the WebSocket and HTTP server on the specified [port].
  ///
  /// Serves an HTML log viewer over HTTP and handles WebSocket connections for real-time logs.
  Future<void> startServer() async {
    if (_isRunning) return;

    _server = await HttpServer.bind(InternetAddress.anyIPv4, _ipPort);
    _isRunning = true;
    _notifySubscribers();
    _server?.listen((HttpRequest request) async {
      if (WebSocketTransformer.isUpgradeRequest(request)) {
        WebSocketTransformer.upgrade(request).then(_handleWsClient);
      } else {
        _serveHtml(request);
      }
    });
  }

  void _handleWsClient(WebSocket client) {
    _clients.add(client);
    client.done.then((_) => _clients.remove(client));
  }

  Future<void> _serveHtml(HttpRequest request) async {
    try {
      final html = await rootBundle.loadString('packages/log_board/assets/log_viewer.html');
      request.response
        ..headers.contentType = ContentType.html
        ..write(html)
        ..close();
    } catch (e) {
      request.response
        ..statusCode = HttpStatus.notFound
        ..write('log_viewer.html not found')
        ..close();
    }
  }

  void _broadcast(String message) {
    String data;
    if (_logTransformer !=null) {
      data = jsonEncode({'log': _logTransformer?.call(message)});
    } else {
      data = jsonEncode({'log': message});
    }
    for (final client in List.from(_clients)) {
      try {
        client.add(data);
      } catch (_) {
        _clients.remove(client);
      }
    }
  }

  /// Stops the WebSocket and HTTP server, disconnects all clients,
  /// and notifies subscribers of the updated server status.
  Future<void> stopServer() async {
    if (!_isRunning) return;
    _isRunning = false;

    for (final client in List.from(_clients)) {
      try {
        await client.close(WebSocketStatus.normalClosure, 'Server stopped');
      } catch (_) {}
    }
    _clients.clear();

    try {
      await _server?.close(force: true);
    } catch (_) {}

    _server = null;
    _notifySubscribers();
  }
}