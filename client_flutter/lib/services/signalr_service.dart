import 'dart:async';
import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:my_chatapp/screens/incoming_call_screen.dart';
import 'package:my_chatapp/services/contact_service.dart';
import 'package:signalr_core/signalr_core.dart';
import 'package:my_chatapp/services/webrtc_service.dart';

class SignalRService {
  HubConnection? _hubConnection;
  final String _serverUrl = "https://secure-chat.spos.ly/signalinghub";

  final StreamController<Map<String, dynamic>> _messageController =
      StreamController.broadcast();
  Stream<Map<String, dynamic>> get onMessageReceived =>
      _messageController.stream;

  final StreamController<Map<String, dynamic>> _webRtcMessageController =
      StreamController.broadcast();
  Stream<Map<String, dynamic>> get onWebRtcMessageReceived =>
      _webRtcMessageController.stream;

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  final ContactService _contactService = ContactService();
  WebRTCService? _webRTCService;
  HubConnectionState? getHubConnectionState() {
    return _hubConnection?.state;
  }

  void setWebRTCService(WebRTCService webRTCService) {
    _webRTCService = webRTCService;
    debugPrint("WebRTCService has been set in SignalRService.");
  }

  Future<void> startConnection(String publicKeyBase64, String userName) async {
    _hubConnection = HubConnectionBuilder()
        .withUrl(
          _serverUrl,
          HttpConnectionOptions(
              logging: (level, message) => debugPrint("SIGNALR_LOG: $message")),
        )
        .build();

    _hubConnection!.onclose(
        (error) => debugPrint("SIGNALR_LOG: Connection Closed: $error"));

    _hubConnection!.on('ReceiveMessage', (arguments) {
      debugPrint('--> [CLIENT] Received a TEXT/FILE message: $arguments');
      if (arguments == null || arguments.length < 3) return;
      _dispatchMessage(arguments, _messageController);
    });

    _hubConnection!.on('WebRtcMessageReceived', (arguments) {
      debugPrint('--> [CLIENT] Received a WEBRTC message: $arguments');
      if (arguments == null || arguments.length < 3) return;

      final String type = arguments[0];
      final dynamic payload = arguments[1];
      final String callerPublicKey = arguments[2];

      if (type == 'offer') {
        final offerPayload = payload is String ? jsonDecode(payload) : payload;
        _handleIncomingCall(offerPayload, callerPublicKey);
      } else if (type == 'hangup') {
        _dispatchMessage(arguments, _webRtcMessageController);
      } else {
        _dispatchMessage(arguments, _webRtcMessageController);
      }
    });

    try {
      await _hubConnection!.start();
      await _hubConnection!
          .invoke('Identify', args: [publicKeyBase64, userName]);
      debugPrint("--- CONNECTION ESTABLISHED SUCCESSFULLY ---");
    } catch (e) {
      debugPrint("❌ FATAL: Failed during connection startup: $e");
      rethrow;
    }
  }

  Future<void> registerDeviceToken(String token) async {
    if (_hubConnection?.state == HubConnectionState.connected) {
      try {
        await _hubConnection!.invoke('RegisterDeviceToken', args: [token]);
        debugPrint("--> [CLIENT] Device token sent to server successfully.");
      } catch (e) {
        debugPrint("--> [CLIENT] Failed to send device token: $e");
      }
    }
  }

  void _dispatchMessage(List<dynamic> arguments,
      StreamController<Map<String, dynamic>> controller) {
    dynamic finalPayload = arguments[1];
    if (finalPayload is String) {
      try {
        finalPayload = jsonDecode(finalPayload);
      } catch (_) {}
    }
    final message = {
      'type': arguments[0],
      'payload': finalPayload,
      'callerPublicKey': arguments[2]
    };
    controller.add(message);
  }

  Future<void> _handleIncomingCall(
      Map<String, dynamic> offer, String callerPublicKey) async {
    final contacts = await _contactService.getContacts();
    final contact =
        contacts.firstWhereOrNull((c) => c.publicKey == callerPublicKey);

    if (contact != null) {
      debugPrint(
          "Incoming call from a known contact. Showing IncomingCallScreen.");
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => IncomingCallScreen(
            callerName: contact.name,
            callerPublicKey: callerPublicKey,
            initialOffer: offer,
          ),
        ),
      );
    } else {
      debugPrint("SPAM call detected from $callerPublicKey. Ignoring.");
    }
  }

  Future<void> _sendMessageInternal(String method, String targetPublicKey,
      String type, dynamic payload) async {
    if (_hubConnection?.state == HubConnectionState.connected) {
      await _hubConnection!
          .invoke(method, args: [targetPublicKey, type, payload]);
    } else {
      debugPrint(
          "Cannot send message: Hub not connected. Current state: ${_hubConnection?.state}");
    }
  }

  Future<void> sendMessage(
      String targetPublicKey, String type, dynamic payload) async {
    await _sendMessageInternal('SendMessage', targetPublicKey, type, payload);
  }

  Future<void> sendWebRtcMessage(
      String targetPublicKey, String type, dynamic payload) async {
    await _sendMessageInternal(
        'SendWebRtcMessage', targetPublicKey, type, payload);
  }

  void dispose() {
    _hubConnection?.stop();
    _messageController.close();
    _webRtcMessageController.close();
  }
}
