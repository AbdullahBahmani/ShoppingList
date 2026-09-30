import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:multipeer_bridge/multipeer_bridge.dart';

import '../models/shopping_list.dart';

/// Device-to-device list transfer over MultipeerConnectivity.
///
/// iOS requires a live radio peer, so this cannot be exercised in the
/// simulator. Discovery is also capped at 8 peers per session by the platform.
class ShareService extends ChangeNotifier {
  ShareService({MultipeerBridge? bridge})
    : _bridge = bridge ?? MultipeerBridge();

  /// MultipeerConnectivity requires 1-15 lowercase ASCII characters.
  static const serviceType = 'shoplist';

  final MultipeerBridge _bridge;
  StreamSubscription<MultipeerEvent>? _sub;

  bool _isStarted = false;
  String _deviceName = 'This device';
  final List<MultipeerPeer> _peers = [];
  final List<SharedListPayload> _inbox = [];
  final List<String> _errors = [];

  bool get isStarted => _isStarted;
  String get displayName => _deviceName;
  List<MultipeerPeer> get peers => List.unmodifiable(_peers);
  List<SharedListPayload> get inbox => List.unmodifiable(_inbox);
  List<String> get errors => List.unmodifiable(_errors);

  /// Peers that have accepted an invitation and can receive payloads.
  List<MultipeerPeer> get connectedPeers =>
      _peers.where((p) => p.state == PeerState.connected).toList();

  /// Starts the native session and begins advertising and browsing.
  Future<void> start() async {
    if (_isStarted) return;
    _isStarted = true;

    _sub = _bridge.events.listen(_handleEvent);

    _deviceName = await _bridge.deviceName();

    try {
      await _bridge.start(
        serviceType: serviceType,
        displayName: _deviceName,
      );
    } on PlatformException catch (e) {
      _errors.add('Sharing unavailable: ${e.message ?? e.code}');
    } on MissingPluginException {
      _errors.add('Sharing is not available on this platform.');
    }

    notifyListeners();
  }

  void _handleEvent(MultipeerEvent event) {
    switch (event) {
      case MultipeerStarted(:final displayName):
        _deviceName = displayName;

      case MultipeerStopped():
        _peers.clear();

      case MultipeerPeersChanged(:final peers):
        _peers
          ..clear()
          ..addAll(peers);

      case MultipeerDataReceived(:final data, :final from):
        final payload = decode(data);
        if (payload == null) {
          _errors.add('Received a list in an unsupported format from $from');
        } else {
          // One inbox entry per sender: a re-send replaces the older copy.
          _inbox.removeWhere((p) => p.fromDevice == payload.fromDevice);
          _inbox.insert(0, payload);
        }

      case MultipeerFailure(:final message):
        _errors.add(message);
    }

    notifyListeners();
  }

  /// Invites a peer into the session. Required before [sendList] on a
  /// peer that has not connected yet.
  Future<void> invite(MultipeerPeer peer) async {
    try {
      await _bridge.invite(peer.id);
    } on PlatformException catch (e) {
      _errors.add('Could not invite ${peer.name}: ${e.message ?? e.code}');
      notifyListeners();
    }
  }

  /// Sends [list] to a peer, inviting it first when needed.
  Future<void> sendList(ShoppingList list, MultipeerPeer peer) async {
    final payload = SharedListPayload(
      fromDevice: _deviceName,
      sentAt: DateTime.now(),
      list: list,
    );

    try {
      if (peer.state != PeerState.connected) {
        await _bridge.invite(peer.id);
      }
      await _bridge.send(peerId: peer.id, data: jsonEncode(payload.toJson()));
    } on PlatformException catch (e) {
      final message = 'Could not send to ${peer.name}: ${e.message ?? e.code}';
      _errors.add(message);
      notifyListeners();
      throw ShareException(message);
    }
  }

  void clearInbox() {
    _inbox.clear();
    _errors.clear();
    notifyListeners();
  }

  /// Stops the native session and releases the event subscription.
  Future<void> stop() async {
    if (!_isStarted) return;
    _isStarted = false;

    try {
      await _bridge.stop();
    } on PlatformException {
      // Already torn down natively.
    } on MissingPluginException {
      // Nothing to tear down.
    }

    await _sub?.cancel();
    _sub = null;
    _peers.clear();

    notifyListeners();
  }

  @override
  void dispose() {
    // dispose() is synchronous, so the native stop is fired and forgotten.
    unawaited(stop());
    super.dispose();
  }

  /// Parses a received payload, returning null when it is malformed.
  static SharedListPayload? decode(String raw) {
    try {
      return SharedListPayload.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }
}

/// Raised when a payload could not be delivered to a peer.
class ShareException implements Exception {
  const ShareException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// A list received from another device, with sender metadata.
@immutable
class SharedListPayload {
  const SharedListPayload({
    required this.fromDevice,
    required this.sentAt,
    required this.list,
  });

  final String fromDevice;
  final DateTime sentAt;
  final ShoppingList list;

  Map<String, dynamic> toJson() => {
    'version': 1,
    'fromDevice': fromDevice,
    'sentAt': sentAt.toIso8601String(),
    'list': list.toJson(),
  };

  factory SharedListPayload.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) {
      throw const FormatException('Unsupported share payload version');
    }

    return SharedListPayload(
      fromDevice: json['fromDevice'] as String? ?? 'Unknown device',
      sentAt:
          DateTime.tryParse(json['sentAt'] as String? ?? '') ?? DateTime.now(),
      list: ShoppingList.fromJson(json['list'] as Map<String, dynamic>),
    );
  }
}
