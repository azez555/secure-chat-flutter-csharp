import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:my_chatapp/core/theme.dart';
import 'package:my_chatapp/models/message_model.dart';
import 'package:my_chatapp/screens/call_screen.dart';
import 'package:my_chatapp/services/contact_service.dart';
import 'package:my_chatapp/services/crypto_service.dart';
import 'package:my_chatapp/services/signalr_service.dart';
import 'package:provider/provider.dart';
import 'package:cryptography/cryptography.dart';

class ConversationScreen extends StatefulWidget {
  final Contact contact;
  const ConversationScreen({super.key, required this.contact});

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final List<Message> _messages = [];

  late final SignalRService _signalRService;
  late final CryptoService _cryptoService;
  late final StreamSubscription _messageSubscription;
  SecretKey? _sharedSecretKey;

  @override
  void initState() {
    super.initState();
    _signalRService = Provider.of<SignalRService>(context, listen: false);
    _cryptoService = Provider.of<CryptoService>(context, listen: false);
    _initializeConversation();
  }

  Future<void> _initializeConversation() async {
    final theirPublicKeyBytes = base64Decode(widget.contact.publicKey);
    final sharedSecretBytes =
        await _cryptoService.createSharedSecret(theirPublicKeyBytes);
    _sharedSecretKey = SecretKey(sharedSecretBytes);

    _messageSubscription =
        _signalRService.onMessageReceived.listen(_handleIncomingMessage);
  }

  void _addMessage(String content, bool isSentByMe) {
    final message = Message(
      content: content,
      timestamp: DateTime.now(),
      isSentByMe: isSentByMe,
    );
    if (mounted) {
      setState(() => _messages.insert(0, message));
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              reverse: true,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12.0, vertical: 20.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isSentByMe = message.isSentByMe;
                final bool showAvatar = (index == _messages.length - 1) ||
                    (_messages[index + 1].isSentByMe != isSentByMe);
                return _MessageBubble(
                  message: message,
                  isSentByMe: isSentByMe,
                  showAvatar: showAvatar,
                  contactInitial: widget.contact.name.isNotEmpty
                      ? widget.contact.name[0].toUpperCase()
                      : '?',
                );
              },
            ),
          ),
          _buildMessageComposer(),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: AppTheme.primary,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: AppTheme.icon),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppTheme.accent,
            child: Text(
              widget.contact.name.isNotEmpty
                  ? widget.contact.name[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            widget.contact.name,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: _startCall,
          icon: const Icon(Icons.call_outlined, color: AppTheme.icon),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildMessageComposer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      decoration: const BoxDecoration(
        color: AppTheme.primary,
        border: Border(top: BorderSide(color: AppTheme.background, width: 1.5)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(24.0),
                ),
                child: TextField(
                  controller: _textController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: const TextStyle(color: AppTheme.textSecondary),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                  ),
                  onChanged: (text) => setState(() {}),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: AppTheme.accent,
              borderRadius: BorderRadius.circular(24),
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap:
                    _textController.text.trim().isEmpty ? null : _sendMessage,
                child: const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Icon(Icons.send, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _messageSubscription.cancel();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.minScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _startCall() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen(
          targetUserPublicKey: widget.contact.publicKey,
          isCaller: true,
        ),
      ),
    );
  }

  Future<void> _handleIncomingMessage(Map<String, dynamic> messageData) async {
    if (!mounted ||
        messageData['callerPublicKey'] != widget.contact.publicKey) {
      return;
    }

    final type = messageData['type'];
    final payload = messageData['payload'];

    if (type == 'text') {
      final decryptedText = await _decryptMessage(payload);
      if (decryptedText != null) {
        _addMessage(decryptedText, false);
      }
    }
  }

  Future<String> _encryptMessage(String plainText) async {
    final algorithm = AesGcm.with256bits();
    final nonce = algorithm.newNonce();
    final secretBox = await algorithm.encrypt(utf8.encode(plainText),
        secretKey: _sharedSecretKey!, nonce: nonce);
    return jsonEncode({
      'ciphertext': base64Encode(secretBox.cipherText),
      'nonce': base64Encode(nonce),
      'mac': base64Encode(secretBox.mac.bytes)
    });
  }

  Future<String?> _decryptMessage(dynamic encryptedPayload) async {
    try {
      final Map<String, dynamic> payload;
      if (encryptedPayload is String) {
        payload = jsonDecode(encryptedPayload);
      } else {
        payload = encryptedPayload;
      }

      final secretBox = SecretBox(base64Decode(payload['ciphertext']),
          nonce: base64Decode(payload['nonce']),
          mac: Mac(base64Decode(payload['mac'])));
      final decryptedBytes = await AesGcm.with256bits()
          .decrypt(secretBox, secretKey: _sharedSecretKey!);
      return utf8.decode(decryptedBytes);
    } catch (e) {
      debugPrint("Decryption failed: $e");
      return null;
    }
  }

  Future<void> _sendMessage() async {
    if (_textController.text.trim().isEmpty) return;
    final text = _textController.text;
    _textController.clear();
    setState(() {});

    _addMessage(text, true);

    final encryptedPayload = await _encryptMessage(text);
    await _signalRService.sendMessage(
        widget.contact.publicKey, 'text', encryptedPayload);
  }
}

class _MessageBubble extends StatelessWidget {
  final Message message;
  final bool isSentByMe;
  final bool showAvatar;
  final String contactInitial;

  const _MessageBubble({
    required this.message,
    required this.isSentByMe,
    required this.showAvatar,
    required this.contactInitial,
  });

  @override
  Widget build(BuildContext context) {
    final alignment =
        isSentByMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final color = isSentByMe ? AppTheme.bubbleMe : AppTheme.bubbleCompanion;
    final borderRadius = isSentByMe
        ? const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(4),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(18))
        : const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(18));

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment:
            isSentByMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isSentByMe && showAvatar)
            CircleAvatar(
                backgroundColor: AppTheme.accent,
                radius: 16,
                child: Text(contactInitial,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold))),
          if (!isSentByMe && !showAvatar) const SizedBox(width: 32),
          if (!isSentByMe) const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: alignment,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration:
                      BoxDecoration(color: color, borderRadius: borderRadius),
                  child: Text(message.content,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 16)),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(DateFormat('HH:mm').format(message.timestamp),
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 12)),
                    if (isSentByMe) ...[
                      const SizedBox(width: 5),
                      const Icon(Icons.done_all,
                          color: AppTheme.accent, size: 16),
                    ],
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
