import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:my_chatapp/core/theme.dart';
import 'package:my_chatapp/main.dart';
import 'package:my_chatapp/services/crypto_service.dart';
import 'package:my_chatapp/services/notification_service.dart';
import 'package:my_chatapp/services/signalr_service.dart';
import 'package:my_chatapp/services/webrtc_service.dart';
import 'package:provider/provider.dart';

class InitializationScreen extends StatefulWidget {
  const InitializationScreen({super.key});

  @override
  State<InitializationScreen> createState() => _InitializationScreenState();
}

class _InitializationScreenState extends State<InitializationScreen> {
  String _statusMessage = "Initializing...";
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  Future<void> _initializeApp() async {
    if (!mounted) return;

    setState(() {
      _hasError = false;
      _statusMessage = "Initializing...";
    });

    try {
      final List<dynamic> activeCalls =
          await FlutterCallkitIncoming.activeCalls();
      Map<String, dynamic>? callToHandle;

      if (activeCalls.isNotEmpty) {
        debugPrint("[INIT_SCREEN] Found an active call payload.");
        callToHandle = Map<String, dynamic>.from(activeCalls[0]);
        FlutterCallkitIncoming.endAllCalls();
      }

      final cryptoService = Provider.of<CryptoService>(context, listen: false);
      final signalRService =
          Provider.of<SignalRService>(context, listen: false);
      final notificationService =
          Provider.of<NotificationService>(context, listen: false);
      final webRTCService = Provider.of<WebRTCService>(context, listen: false);

      setState(() => _statusMessage = "Loading cryptographic keys...");
      await cryptoService.initialize();

      setState(() => _statusMessage = "Preparing call service...");
      await webRTCService.initialize();

      setState(() => _statusMessage = "Initializing notifications...");
      await notificationService.initialize();

      setState(() => _statusMessage = "Connecting to server...");
      await signalRService
          .startConnection(
              await cryptoService.getPublicKeyBase64(), "Flutter User")
          .timeout(const Duration(seconds: 15));

      setState(() => _statusMessage = "Registering device...");
      final deviceToken = await notificationService.getDeviceToken();
      if (deviceToken != null) {
        await signalRService.registerDeviceToken(deviceToken);
      }

      if (callToHandle != null && mounted) {
        debugPrint(
            "[INIT_SCREEN] Services initialized. Navigating to IncomingCallScreen.");

        final Map<String, dynamic> extra =
            Map<String, dynamic>.from(callToHandle['extra'] as Map? ?? {});
        final String callerName = extra['callerName'] ?? 'Unknown';
        final String callerPublicKey = extra['callerPublicKey'] ?? '';
        final String sdp = extra['sdp'] ?? '';

        if (callerPublicKey.isNotEmpty && sdp.isNotEmpty) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            AppRoutes.incomingCall,
            (route) => false,
            arguments: IncomingCallArguments(
              callerName: callerName,
              callerPublicKey: callerPublicKey,
              initialOffer: jsonDecode(sdp),
            ),
          );
        } else {
          debugPrint(
              "[INIT_SCREEN] Call data was corrupt. Navigating to contacts.");
          Navigator.of(context)
              .pushNamedAndRemoveUntil(AppRoutes.contacts, (route) => false);
        }
      } else if (mounted) {
        debugPrint(
            "[INIT_SCREEN] Normal startup. Navigating to ContactsScreen.");
        Navigator.of(context)
            .pushNamedAndRemoveUntil(AppRoutes.contacts, (route) => false);
      }
    } on TimeoutException catch (_) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _statusMessage =
              "Connection Timed Out.\nPlease check your internet and try again.";
        });
      }
    } catch (e, s) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _statusMessage =
              "Connection Failed!\nPlease check your internet connection.";
        });
        debugPrint("Initialization Error: ${e.toString()}");
        debugPrint("Stack Trace: ${s.toString()}");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: AppTheme.accent,
            ),
            const SizedBox(height: 24),
            Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 16, color: AppTheme.textSecondary),
            ),
            if (_hasError)
              Padding(
                padding: const EdgeInsets.only(top: 30),
                child: ElevatedButton(
                  onPressed: _initializeApp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30.0),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 15),
                    elevation: 5,
                  ),
                  child: const Text(
                    'Retry',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
