import 'dart:async';

import 'package:flutter/services.dart';

/// Connection state of a discovered peer.
enum PeerState { notConnected, connecting, connected }

PeerState _parseState(String? value) => switch (value) {
  'connected' => PeerState.connected,
  'connecting' => PeerState.connecting,
  _ => PeerState.notConnected,
};

/// A nearby device discovered over MultipeerConnectivity.
class MultipeerPeer {
  const MultipeerPeer({
    required this.id,
    required this.name,
    required this.state,
  });

  final String id;
  final String name;
  final PeerState state;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MultipeerPeer &&
          other.id == id &&
          other.name == name &&
          other.state == state;

  @override
  int get hashCode => Object.hash(id, name, state);
}

/// Events emitted by the native MultipeerConnectivity session.
sealed class MultipeerEvent {
  const MultipeerEvent();
}

class MultipeerStarted extends MultipeerEvent {
  const MultipeerStarted(this.displayName);
  final String displayName;
}

class MultipeerStopped extends MultipeerEvent {
  const MultipeerStopped();
}

class MultipeerPeersChanged extends MultipeerEvent {
  const MultipeerPeersChanged(this.peers);
  final List<MultipeerPeer> peers;
}

class MultipeerDataReceived extends MultipeerEvent {
  const MultipeerDataReceived(this.data, this.from);
  final String data;
  final String from;
}

class MultipeerFailure extends MultipeerEvent {
  const MultipeerFailure(this.message);
  final String message;
}

/// Dart interface to the native MultipeerConnectivity bridge.
///
/// iOS requires a live radio peer, so this cannot be exercised in the
/// simulator; discovery is also capped at 8 peers per session.
class MultipeerBridge {
  MultipeerBridge();

  static const MethodChannel _channel = MethodChannel('multipeer_bridge');

  final _events = StreamController<MultipeerEvent>.broadcast();
  Stream<MultipeerEvent> get events => _events.stream;

  /// Best-effort human-friendly name for this device.
  Future<String> deviceName() async {
    try {
      return await _channel.invokeMethod<String>('deviceName') ?? 'This device';
    } on PlatformException {
      return 'This device';
    } on MissingPluginException {
      return 'This device';
    }
  }

  /// Starts advertising and browsing for nearby peers.
  Future<void> start({
    required String serviceType,
    required String displayName,
  }) async {
    _channel.setMethodCallHandler(_handleCall);
    await _channel.invokeMethod<void>('start', {
      'serviceType': serviceType,
      'displayName': displayName,
    });
  }

  Future<void> _handleCall(MethodCall call) async {
    if (call.method != 'event') return;
    final args = (call.arguments as Map?)?.cast<String, dynamic>();
    if (args == null) return;

    switch (args['type'] as String?) {
      case 'started':
        _events.add(
          MultipeerStarted(args['displayName'] as String? ?? 'This device'),
        );
      case 'stopped':
        _events.add(const MultipeerStopped());
      case 'peerChanged':
        final raw = (args['peers'] as List?) ?? const [];
        _events.add(
          MultipeerPeersChanged(
            raw
                .whereType<Map>()
                .map(
                  (e) => MultipeerPeer(
                    id: e['id'] as String? ?? '',
                    name: e['name'] as String? ?? 'Unknown device',
                    state: _parseState(e['state'] as String?),
                  ),
                )
                .toList(),
          ),
        );
      case 'data':
        _events.add(
          MultipeerDataReceived(
            args['data'] as String? ?? '',
            args['from'] as String? ?? 'Unknown device',
          ),
        );
      case 'error':
        _events.add(
          MultipeerFailure(args['message'] as String? ?? 'Sharing error'),
        );
    }
  }

  /// Invites a peer into the session. Required before [send] on a fresh peer.
  Future<void> invite(String peerId) =>
      _channel.invokeMethod<void>('invite', {'peerId': peerId});

  /// Sends a payload to an already-connected peer.
  Future<void> send({
    required String peerId,
    required String data,
  }) => _channel.invokeMethod<void>('send', {
    'peerId': peerId,
    'data': data,
  });

  Future<void> stop() => _channel.invokeMethod<void>('stop');

  Future<void> dispose() async {
    await _events.close();
  }
}
