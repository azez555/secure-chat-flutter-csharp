import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:my_chatapp/core/theme.dart';
import 'package:my_chatapp/main.dart';
import 'package:my_chatapp/services/contact_service.dart';
import 'package:my_chatapp/services/webrtc_service.dart';
import 'package:provider/provider.dart';

class CallScreen extends StatefulWidget {
  final String targetUserPublicKey;
  final bool isCaller;

  const CallScreen({
    super.key,
    required this.targetUserPublicKey,
    required this.isCaller,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  StreamSubscription? _callEndedSubscription;
  bool _showControls = true;
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  String _contactName = "Loading...";

  Timer? _callTimer;
  int _callDurationInSeconds = 0;
  String _callStatus = "Connecting...";

  @override
  void initState() {
    super.initState();
    final webRTCService = Provider.of<WebRTCService>(context, listen: false);

    _initializeCall(webRTCService);
    _loadContactName();

    _callEndedSubscription = webRTCService.onCallEnded.listen((_) {
      _navigateHome();
    });

    webRTCService.onConnectionStateChange = (state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        if (mounted) _startCallTimer();
      }
    };
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _callEndedSubscription?.cancel();

    final webRTCService = Provider.of<WebRTCService>(context, listen: false);
    webRTCService.onConnectionStateChange = null;

    super.dispose();
  }

  void _loadContactName() async {
    final contactService = Provider.of<ContactService>(context, listen: false);
    final contact =
        await contactService.getContactByPublicKey(widget.targetUserPublicKey);
    if (contact != null && mounted) {
      setState(() => _contactName = contact.name);
    } else if (mounted) {
      setState(() => _contactName = "Unknown Contact");
    }
  }

  Future<void> _initializeCall(WebRTCService webRTCService) async {
    if (widget.isCaller) {
      await webRTCService.startCall(widget.targetUserPublicKey);
    }
  }

  void _startCallTimer() {
    if (_callTimer != null && _callTimer!.isActive) return;
    setState(() => _callStatus = "Connected");
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _callDurationInSeconds++;
      });
    });
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds / 60).floor().toString().padLeft(2, '0');
    final remainingSeconds = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remainingSeconds';
  }

  void _navigateHome() {
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.contacts,
        (route) => false,
      );
    }
  }

  void _hangUpAndExit() {
    final webRTCService = context.read<WebRTCService>();
    webRTCService.hangUp(
      notifyRemote: true,
      remotePublicKey: widget.targetUserPublicKey,
    );

    _navigateHome();
  }

  void _toggleMute() {
    final webRTCService = context.read<WebRTCService>();
    setState(() => _isMuted = !_isMuted);
    webRTCService.toggleMute(_isMuted);
  }

  void _toggleSpeaker() {
    final webRTCService = context.read<WebRTCService>();
    setState(() => _isSpeakerOn = !_isSpeakerOn);
    webRTCService.toggleSpeaker(_isSpeakerOn);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: GestureDetector(
        onTap: () => setState(() => _showControls = !_showControls),
        child: Stack(
          alignment: Alignment.center,
          children: [
            _buildAudioCallUI(),
            AnimatedOpacity(
              opacity: _showControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: _buildControlsOverlay(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioCallUI() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 2),
          CircleAvatar(
            radius: 60,
            backgroundColor: AppTheme.accent.withOpacity(0.8),
            child: const Icon(Icons.person, size: 80, color: Colors.white),
          ),
          const SizedBox(height: 24),
          Text(
            _contactName,
            style: const TextStyle(
                fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            _callStatus == "Connected"
                ? _formatDuration(_callDurationInSeconds)
                : _callStatus,
            style: const TextStyle(fontSize: 16, color: AppTheme.textSecondary),
          ),
          const Spacer(flex: 3),
        ],
      ),
    );
  }

  Widget _buildControlsOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.3),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 30.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildCallButton(
                    icon: _isSpeakerOn
                        ? Icons.volume_up_outlined
                        : Icons.volume_down_outlined,
                    onPressed: _toggleSpeaker,
                    backgroundColor: _isSpeakerOn ? AppTheme.accent : null,
                  ),
                  _buildCallButton(
                    icon: _isMuted
                        ? Icons.mic_off_outlined
                        : Icons.mic_none_outlined,
                    onPressed: _toggleMute,
                    backgroundColor: _isMuted ? AppTheme.accent : null,
                  ),
                  _buildCallButton(
                    icon: Icons.call_end,
                    onPressed: _hangUpAndExit,
                    backgroundColor: Colors.red,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallButton({
    required IconData icon,
    required VoidCallback onPressed,
    Color? backgroundColor,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: backgroundColor ?? Colors.white.withOpacity(0.3),
        ),
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }
}
