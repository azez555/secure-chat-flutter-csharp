import 'package:flutter/material.dart';
import 'package:my_chatapp/core/theme.dart';
import 'package:my_chatapp/screens/contacts_screen.dart';
import 'package:my_chatapp/screens/incoming_call_screen.dart';
import 'package:my_chatapp/screens/initialization_screen.dart';
import 'package:my_chatapp/services/contact_service.dart';
import 'package:my_chatapp/services/crypto_service.dart';
import 'package:my_chatapp/services/database_service.dart';
import 'package:my_chatapp/services/signalr_service.dart';
import 'package:my_chatapp/services/webrtc_service.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:my_chatapp/services/notification_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:my_chatapp/services/audio_service.dart';

class AppRoutes {
  static const initialization = '/';
  static const contacts = '/contacts';
  static const incomingCall = '/incoming-call';
}

class IncomingCallArguments {
  final String callerName;
  final String callerPublicKey;
  final Map<String, dynamic> initialOffer;

  IncomingCallArguments({
    required this.callerName,
    required this.callerPublicKey,
    required this.initialOffer,
  });
}

const AndroidNotificationChannel messagesChannel = AndroidNotificationChannel(
  'messages_channel',
  'Messages',
  description: 'Channel for text message notifications.',
  importance: Importance.defaultImportance,
);

const AndroidNotificationChannel callsChannel = AndroidNotificationChannel(
  'calls_channel',
  'Incoming Calls',
  description: 'Channel for incoming call notifications.',
  importance: Importance.max,
  sound: RawResourceAndroidNotificationSound('ringtone_default'),
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(messagesChannel);
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(callsChannel);

  final cryptoService = CryptoService();
  final signalRService = SignalRService();
  final audioService = AudioService();

  final webRTCService = WebRTCService(
    signalRService,
    cryptoService,
    onStateChange: () {},
    audioService: audioService,
  );
  final notificationService = NotificationService(
      navigatorKey: signalRService.navigatorKey, webRTCService: webRTCService);

  signalRService.setWebRTCService(webRTCService);

  runApp(
    MyApp(
      cryptoService: cryptoService,
      signalRService: signalRService,
      notificationService: notificationService,
      webRTCService: webRTCService,
      audioService: audioService,
    ),
  );
}

class MyApp extends StatelessWidget {
  final CryptoService cryptoService;
  final SignalRService signalRService;
  final NotificationService notificationService;
  final WebRTCService webRTCService;
  final AudioService audioService;

  const MyApp({
    super.key,
    required this.cryptoService,
    required this.signalRService,
    required this.notificationService,
    required this.webRTCService,
    required this.audioService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<CryptoService>.value(value: cryptoService),
        Provider<SignalRService>.value(value: signalRService),
        Provider<NotificationService>.value(value: notificationService),
        Provider<WebRTCService>.value(value: webRTCService),
        Provider<AudioService>.value(value: audioService),
        Provider<DatabaseService>(create: (_) => DatabaseService()),
        Provider<ContactService>(create: (_) => ContactService()),
      ],
      child: MaterialApp(
        title: 'Secure Chat',
        theme: AppTheme.darkTheme,
        navigatorKey: signalRService.navigatorKey,
        debugShowCheckedModeBanner: false,
        initialRoute: AppRoutes.initialization,
        onGenerateRoute: (settings) {
          switch (settings.name) {
            case AppRoutes.initialization:
              return MaterialPageRoute(
                  builder: (_) => const InitializationScreen());
            case AppRoutes.contacts:
              return MaterialPageRoute(builder: (_) => const ContactsScreen());
            case AppRoutes.incomingCall:
              final args = settings.arguments as IncomingCallArguments;
              return MaterialPageRoute(
                builder: (_) => IncomingCallScreen(
                  callerName: args.callerName,
                  callerPublicKey: args.callerPublicKey,
                  initialOffer: args.initialOffer,
                ),
              );
            default:
              return MaterialPageRoute(
                  builder: (_) => const InitializationScreen());
          }
        },
      ),
    );
  }
}
