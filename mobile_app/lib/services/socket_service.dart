import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  IO.Socket? socket;
  final _connectionStatusController = StreamController<bool>.broadcast();
  final _systemStatsController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<bool> get connectionStatus => _connectionStatusController.stream;
  Stream<Map<String, dynamic>> get systemStats => _systemStatsController.stream;

  void connect(String ip, String token) {
    if (socket != null) socket!.dispose();

    socket = IO.io('http://$ip:5000',
      IO.OptionBuilder()
        .setTransports(['websocket'])
        .setExtraHeaders({'X-Auth-Token': token})
        .enableAutoConnect()
        .build()
    );

    socket!.onConnect((_) {
      print("Socket Connected");
      _connectionStatusController.add(true);
    });

    socket!.onDisconnect((_) {
      print("Socket Disconnected");
      _connectionStatusController.add(false);
    });

    socket!.on('system_stats', (data) {
      _systemStatsController.add(Map<String, dynamic>.from(data));
    });

    socket!.connect();
  }

  void dispose() {
    socket?.dispose();
    _connectionStatusController.close();
    _systemStatsController.close();
  }
}
