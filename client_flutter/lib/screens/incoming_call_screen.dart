import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:my_chatapp/core/theme.dart';
import 'package:my_chatapp/screens/call_screen.dart';
import 'package:my_chatapp/services/webrtc_service.dart';
import 'package:provider/provider.dart';

class IncomingCallScreen extends StatefulWidget {
  final String callerName;
  final String callerPublicKey;
  final Map<String, dynamic> initialOffer;

  const IncomingCallScreen({
    super.key,
    required this.callerName,
    required this.callerPublicKey,
    required this.initialOffer,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  late final AudioPlayer _audioPlayer;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _playRingtone();
  }

  void _playRingtone() async {
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.play(AssetSource('audio/incoming_ringtone.mp3'));
    } catch (e) {
      debugPrint("Error playing ringtone: $e");
    }
  }

  void _stopRingtone() {
    _audioPlayer.stop();
  }

  @override
  void dispose() {
    _stopRingtone();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _answerCall() async {
    _stopRingtone();

    final webRtcService = context.read<WebRTCService>();

    await webRtcService.answerCall(widget.initialOffer, widget.callerPublicKey);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => CallScreen(
            targetUserPublicKey: widget.callerPublicKey,
            isCaller: false,
          ),
        ),
      );
    }
  }

  void _rejectCall() {
    _stopRingtone();

    final webRTCService = context.read<WebRTCService>();

    webRTCService.hangUp(
      notifyRemote: true,
      remotePublicKey: widget.callerPublicKey,
    );

    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              CircleAvatar(
                radius: 60,
                backgroundColor: AppTheme.accent,
                child: Text(
                  widget.callerName.isNotEmpty
                      ? widget.callerName.substring(0, 1).toUpperCase()
                      : '?',
                  style: const TextStyle(
                      fontSize: 60,
                      color: Colors.white,
                      fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                widget.callerName,
                style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              const SizedBox(height: 8),
              const Text(
                'Incoming Call...',
                style: TextStyle(fontSize: 18, color: AppTheme.textSecondary),
              ),
              const Spacer(flex: 3),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildCallButton(
                      icon: Icons.call_end,
                      label: 'Decline',
                      backgroundColor: Colors.red,
                      onPressed: _rejectCall),
                  _buildCallButton(
                      icon: Icons.call,
                      label: 'Accept',
                      backgroundColor: Colors.green,
                      onPressed: _answerCall),
                ],
              ),
              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCallButton(
      {required IconData icon,
      required String label,
      required Color backgroundColor,
      required VoidCallback onPressed}) {
    return Column(
      children: [
        GestureDetector(
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration:
                BoxDecoration(shape: BoxShape.circle, color: backgroundColor),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 16)),
      ],
    );
  }
}
