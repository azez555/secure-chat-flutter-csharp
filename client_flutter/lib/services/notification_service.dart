import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_callkit_incoming/entities/android_params.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/entities/call_event.dart';
import 'package:my_chatapp/services/webrtc_service.dart';
import 'package:my_chatapp/screens/incoming_call_screen.dart';
import 'dart:convert';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Background handler received a message: ${message.data}");

  String? notificationType = message.data['notification_type'];

  if (notificationType == 'incoming_call') {
    await showCallkitIncoming(message.data);
  } else if (notificationType == 'text_message') {
    await showLocalNotification(message);
  }
}

Future<void> showCallkitIncoming(Map<String, dynamic> data) async {
  final params = CallKitParams(
    id: data['id'] ?? const Uuid().v4(),
    nameCaller: data['nameCaller'] ?? 'Unknown',
    appName: 'Secure Chat',
    handle: data['handle'],
    type: 0,
    duration: 30000,
    textAccept: 'Accept',
    textDecline: 'Decline',
    extra: <String, dynamic>{
      'callerPublicKey': data['callerPublicKey'],
      'callerName': data['nameCaller'],
      'sdp': data['handle'],
    },
    android: const AndroidParams(
      isCustomNotification: true,
      isShowLogo: false,
      ringtonePath: 'ringtone_default',
      backgroundColor: '#091C40',
      actionColor: '#4CAF50',
    ),
  );
  await FlutterCallkitIncoming.showCallkitIncoming(params);
}

Future<void> showLocalNotification(RemoteMessage message) async {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
    'messages_channel',
    'Messages',
    channelDescription: 'Channel for text message notifications',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
  );

  const NotificationDetails platformChannelSpecifics =
      NotificationDetails(android: androidPlatformChannelSpecifics);

  await flutterLocalNotificationsPlugin.show(
    message.hashCode,
    message.notification?.title ?? 'New Message',
    message.notification?.body ?? 'You have a new message.',
    platformChannelSpecifics,
  );
}

class NotificationService {
  final GlobalKey<NavigatorState> navigatorKey;
  StreamSubscription? _callkitSubscription;
  final WebRTCService webRTCService;
  NotificationService({
    required this.navigatorKey,
    required this.webRTCService,
  });
  Future<void> initialize() async {
    await FirebaseMessaging.instance.requestPermission();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint("Foreground handler received a message: ${message.data}");
      String? notificationType = message.data['notification_type'];

      if (notificationType == 'incoming_call') {
        showCallkitIncoming(message.data);
      } else if (notificationType == 'text_message') {
        debugPrint("Foreground: Received a text message.");
      }
    });

    _callkitSubscription = FlutterCallkitIncoming.onEvent.listen((event) {
      if (event == null) return;

      if (event.event == Event.actionCallAccept) {
        final body = event.body as Map<String, dynamic>;
        final extra = body['extra'] as Map<String, dynamic>;

        final String callerPublicKey = extra['callerPublicKey'] ?? '';
        final String callerName = body['nameCaller'] ?? 'Unknown';
        final String sdp = body['handle'] as String? ?? '';

        if (callerPublicKey.isNotEmpty && sdp.isNotEmpty) {
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (context) => IncomingCallScreen(
                callerName: callerName,
                callerPublicKey: callerPublicKey,
                initialOffer: jsonDecode(sdp),
              ),
            ),
          );
        }
      } else if (event.event == Event.actionCallDecline ||
          event.event == Event.actionCallTimeout) {
        FlutterCallkitIncoming.endCall(event.body['id']);
      }
    });
  }

  Future<String?> getDeviceToken() async {
    return await FirebaseMessaging.instance.getToken();
  }

  void dispose() {
    _callkitSubscription?.cancel();
  }
}
