import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../domain/entities/entities.dart';

/// Live telemetry over the local network (TLS WebSocket on the Core).
/// Not used by default (see AppConfig). Message format (JSON, 1 Hz):
/// `{"t":1729500000,"wh":860.2,"soc":0.84,"pv":2140,"load":610,"grid":-1490,
///   "bat":40,"gridOk":true,"mode":"selfConsumption","soh":100}`
class LiveLinkSource {
  LiveLinkSource(this.uri);
  final Uri uri;
  WebSocketChannel? _channel;

  Stream<Map<String, dynamic>> telemetry() {
    _channel ??= WebSocketChannel.connect(uri);
    return _channel!.stream
        .map((e) => jsonDecode(e as String))
        .where((e) => e is Map<String, dynamic>)
        .cast<Map<String, dynamic>>();
  }

  /// Commands are signed by the owner key; the signature travels with them.
  void send(String command, Map<String, Object?> args,
      {required String signature}) {
    _channel?.sink
        .add(jsonEncode({'cmd': command, 'args': args, 'sig': signature}));
  }

  static EnergyMode parseMode(String raw) =>
      EnergyMode.values.firstWhere((m) => m.name == raw,
          orElse: () => EnergyMode.selfConsumption);

  Future<void> close() async => _channel?.sink.close();
}
