import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:my_chatapp/services/crypto_service.dart';
import 'package:my_chatapp/services/signalr_service.dart';
import 'package:cryptography/cryptography.dart';
import 'package:my_chatapp/services/audio_service.dart';

class WebRTCService {
  final SignalRService _signalRService;
  final CryptoService _cryptoService;
  final Function() onStateChange;
  final AudioService _audioService;

  List<RTCIceCandidate> _iceCandidateQueue = [];

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  static bool _isCallInProgress = false;
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();
  final StreamController<bool> _onCallEndedController =
      StreamController.broadcast();
  Stream<bool> get onCallEnded => _onCallEndedController.stream;
  Function(RTCPeerConnectionState)? onConnectionStateChange;

  WebRTCService(
    this._signalRService,
    this._cryptoService, {
    required this.onStateChange,
    required AudioService audioService,
  }) : _audioService = audioService;

  Future<void> initialize() async {
    await remoteRenderer.initialize();
    _signalRService.onWebRtcMessageReceived.listen((message) {
      final type = message['type'];
      final payload = message['payload'];
      final callerPublicKey = message['callerPublicKey'];
      switch (type) {
        case 'answer':
          _handleAnswer(payload, callerPublicKey);
          break;
        case 'candidate':
          _handleCandidate(payload);
          break;
        case 'hangup':
          if (_isCallInProgress) {
            hangUp(notifyRemote: false);
          }
          break;
      }
    });
  }

  Future<void> _handleCandidate(Map<String, dynamic> candidateMap) async {
    final candidate = RTCIceCandidate(
      candidateMap['candidate'],
      candidateMap['sdpMid'],
      candidateMap['sdpMLineIndex'],
    );

    if (_peerConnection != null &&
        (await _peerConnection!.getRemoteDescription()) != null) {
      debugPrint("✅ ICE Candidate: Adding directly.");
      await _peerConnection!.addCandidate(candidate);
    } else {
      debugPrint("🟡 ICE Candidate: Queued for later.");
      _iceCandidateQueue.add(candidate);
    }
  }

  Future<void> answerCall(
      Map<String, dynamic> initialOffer, String callerPublicKey) async {
    if (_isCallInProgress) {
      debugPrint(
          "SmartPatch: Ignoring answerCall, a call is already in progress.");
      return;
    }
    _isCallInProgress = true;
    onStateChange();

    try {
      final sharedSecret = await _cryptoService
          .createSharedSecret(base64Decode(callerPublicKey));
      final decryptedSdp = await _decryptSdp(initialOffer, sharedSecret);
      if (decryptedSdp == null) throw Exception("Failed to decrypt offer SDP.");

      await openUserMedia();
      await _createPeerConnection(callerPublicKey);
      await _peerConnection!
          .setRemoteDescription(RTCSessionDescription(decryptedSdp, 'offer'));

      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);

      if (_iceCandidateQueue.isNotEmpty) {
        debugPrint(
            "⚙️ Processing ${_iceCandidateQueue.length} queued ICE candidates in answerCall...");
        for (final candidate in _iceCandidateQueue) {
          await _peerConnection!.addCandidate(candidate);
        }
        _iceCandidateQueue.clear();
      }

      final encryptedAnswer = await _encryptSdp(answer.sdp!, sharedSecret);
      _signalRService.sendWebRtcMessage(
          callerPublicKey, 'answer', encryptedAnswer);
      debugPrint("✅ Call answered and answer sent to caller.");
    } catch (e) {
      debugPrint("Error during answerCall: $e");
      await hangUp(notifyRemote: true, remotePublicKey: callerPublicKey);
    }
  }

  Future<void> _handleAnswer(
      Map<String, dynamic> encryptedAnswer, String remotePartyKey) async {
    await _audioService.stopAllSounds();
    final sharedSecret =
        await _cryptoService.createSharedSecret(base64Decode(remotePartyKey));
    final decryptedSdp = await _decryptSdp(encryptedAnswer, sharedSecret);

    if (decryptedSdp != null) {
      await _peerConnection
          ?.setRemoteDescription(RTCSessionDescription(decryptedSdp, 'answer'));

      if (_iceCandidateQueue.isNotEmpty) {
        debugPrint(
            "⚙️ Processing ${_iceCandidateQueue.length} queued ICE candidates in _handleAnswer...");
        for (final candidate in _iceCandidateQueue) {
          await _peerConnection!.addCandidate(candidate);
        }
        _iceCandidateQueue.clear();
      }
    }
  }

  Future<void> openUserMedia() async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': false
    };
    try {
      _localStream =
          await navigator.mediaDevices.getUserMedia(mediaConstraints);
    } catch (e) {
      debugPrint("Error opening media devices: $e");
      rethrow;
    }
  }

  Future<void> _createPeerConnection(String targetPublicKey) async {
    if (_peerConnection != null) {
      await _peerConnection!.close();
    }

    final Map<String, dynamic> configuration = {'iceServers': []};

    _peerConnection = await createPeerConnection(configuration);

    _localStream?.getTracks().forEach((track) {
      _peerConnection!.addTrack(track, _localStream!);
    });

    _peerConnection!.onIceCandidate = (candidate) {
      if (candidate != null) {
        _signalRService.sendWebRtcMessage(
            targetPublicKey, 'candidate', candidate.toMap());
      }
    };

    _peerConnection!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        remoteRenderer.srcObject = event.streams[0];
        onStateChange();
      }
    };

    _peerConnection!.onConnectionState = (state) {
      debugPrint("[WebRTC] Connection State changed: $state");
      onConnectionStateChange?.call(state);
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        hangUp(notifyRemote: false);
      }
    };
  }

  Future<void> startCall(String targetPublicKey) async {
    if (_isCallInProgress) {
      debugPrint(
          "SmartPatch: Ignoring startCall, a call is already in progress.");
      return;
    }
    _isCallInProgress = true;
    onStateChange();
    try {
      await openUserMedia();
      await _createPeerConnection(targetPublicKey);
      final offer = await _peerConnection!.createOffer(
          {'offerToReceiveAudio': true, 'offerToReceiveVideo': false});
      await _peerConnection!.setLocalDescription(offer);
      final sharedSecret = await _cryptoService
          .createSharedSecret(base64Decode(targetPublicKey));
      final encryptedOffer = await _encryptSdp(offer.sdp!, sharedSecret);
      _signalRService.sendWebRtcMessage(
          targetPublicKey, 'offer', encryptedOffer);
    } catch (e) {
      debugPrint("Error creating/sending offer: $e");
      await hangUp(notifyRemote: true, remotePublicKey: targetPublicKey);
    }
  }

  Future<void> hangUp(
      {bool notifyRemote = true, String? remotePublicKey}) async {
    await _audioService.stopAllSounds();
    if (!_isCallInProgress) {
      debugPrint("hangUp called, but no call is in progress. Ignoring.");
      return;
    }
    if (notifyRemote && remotePublicKey != null) {
      _signalRService.sendWebRtcMessage(remotePublicKey, 'hangup', {});
    }
    try {
      _localStream?.getTracks().forEach((track) {
        track.stop();
      });
      await _localStream?.dispose();
      _localStream = null;
    } catch (e) {/* ... */}
    try {
      await _peerConnection?.close();
      _peerConnection = null;
      remoteRenderer.srcObject = null;
    } catch (e) {/* ... */}
    _isCallInProgress = false;
    if (!_onCallEndedController.isClosed) {
      _onCallEndedController.add(true);
    }
    onStateChange();
  }

  void dispose() {
    hangUp(notifyRemote: false);
    remoteRenderer.dispose();
  }

  void toggleMute(bool isMuted) => _localStream
      ?.getAudioTracks()
      .forEach((track) => track.enabled = !isMuted);
  void toggleSpeaker(bool isSpeakerOn) => _localStream
      ?.getAudioTracks()
      .forEach((track) => Helper.setSpeakerphoneOn(isSpeakerOn));

  Future<Map<String, String>> _encryptSdp(String sdp, Uint8List key) async {
    final algorithm = AesGcm.with256bits();
    final nonce = algorithm.newNonce();
    final secretBox = await algorithm.encrypt(utf8.encode(sdp),
        secretKey: SecretKey(key), nonce: nonce);
    return {
      'ciphertext': base64Encode(secretBox.cipherText),
      'nonce': base64Encode(nonce),
      'mac': base64Encode(secretBox.mac.bytes)
    };
  }

  Future<String?> _decryptSdp(
      Map<String, dynamic> payload, Uint8List key) async {
    try {
      final algorithm = AesGcm.with256bits();
      final secretBox = SecretBox(base64Decode(payload['ciphertext']),
          nonce: base64Decode(payload['nonce']),
          mac: Mac(base64Decode(payload['mac'])));
      final decryptedBytes =
          await algorithm.decrypt(secretBox, secretKey: SecretKey(key));
      return utf8.decode(decryptedBytes);
    } catch (e) {
      debugPrint("Decryption failed: $e");
      return null;
    }
  }
}
