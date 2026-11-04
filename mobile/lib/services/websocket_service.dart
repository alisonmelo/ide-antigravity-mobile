import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

enum ConnectionStatus { disconnected, connecting, connected, error }

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  WebSocketChannel? _channel;
  ConnectionStatus status = ConnectionStatus.disconnected;

  final _statusController = StreamController<ConnectionStatus>.broadcast();
  Stream<ConnectionStatus> get statusStream => _statusController.stream;

  final _messagesController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get messagesStream => _messagesController.stream;

  String? currentHost;
  int? currentPort;
  String? currentToken;

  void connect({required String host, required int port, required String token}) {
    currentHost = host;
    currentPort = port;
    currentToken = token;

    _updateStatus(ConnectionStatus.connecting);

    try {
      final uri = Uri.parse('ws://$host:$port/ws');
      _channel = WebSocketChannel.connect(uri);

      _channel!.stream.listen(
        (data) {
          try {
            final json = jsonDecode(data as String) as Map<String, dynamic>;
            if (json['type'] == 'auth_ok') {
              _updateStatus(ConnectionStatus.connected);
            }
            _messagesController.add(json);
          } catch (e) {
            // Raw text or non-json message
          }
        },
        onError: (error) {
          _updateStatus(ConnectionStatus.error);
        },
        onDone: () {
          _updateStatus(ConnectionStatus.disconnected);
        },
      );

      // Enviar mensagem de autenticação inicial
      send({'type': 'auth', 'token': token});
    } catch (e) {
      _updateStatus(ConnectionStatus.error);
    }
  }

  void _updateStatus(ConnectionStatus newStatus) {
    status = newStatus;
    _statusController.add(status);
  }

  void send(Map<String, dynamic> message) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode(message));
    }
  }

  void sendPrompt(String prompt, {String? apiKey}) {
    send({
      'type': 'prompt',
      'content': prompt,
      if (apiKey != null && apiKey.isNotEmpty) 'api_key': apiKey,
    });
  }

  void listFiles({String? path}) {
    send({
      'type': 'list_files',
      if (path != null) 'path': path,
    });
  }

  void readFile(String path) {
    send({
      'type': 'read_file',
      'path': path,
    });
  }

  void saveFile(String path, String content) {
    send({
      'type': 'save_file',
      'path': path,
      'content': content,
    });
  }

  void runCommand(String command) {
    send({
      'type': 'run_command',
      'command': command,
    });
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
    _updateStatus(ConnectionStatus.disconnected);
  }
}
