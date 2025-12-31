import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_chatapp/core/theme.dart';
import 'package:my_chatapp/screens/qr_display_screen.dart';
import 'package:my_chatapp/services/crypto_service.dart';
import 'package:provider/provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _publicKey = 'Loading...';
  String _fingerprint = 'Loading...';

  @override
  void initState() {
    super.initState();
    _loadKeys();
  }

  Future<void> _loadKeys() async {
    final cryptoService = Provider.of<CryptoService>(context, listen: false);
    final pk = await cryptoService.getPublicKeyBase64();
    final fp = await cryptoService.getPublicKeyFingerprint();
    if (mounted) {
      setState(() {
        _publicKey = pk;
        _fingerprint = fp;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Show my QR Code',
            onPressed: () {
              if (_publicKey != 'Loading...') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => QrDisplayScreen(data: _publicKey)),
                );
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 20),
          const Center(
            child: CircleAvatar(
              radius: 50,
              backgroundColor: AppTheme.accent,
              child: Text('ME',
                  style: TextStyle(
                      fontSize: 40,
                      color: Colors.white,
                      fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text('My Account',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 30),
          _buildInfoCard(
            context,
            'Fingerprint',
            _fingerprint,
            Icons.fingerprint,
            'This is your unique security fingerprint. Share it with your contacts to verify your identity.',
          ),
          _buildInfoCard(
            context,
            'Public Key',
            _publicKey,
            Icons.vpn_key_outlined,
            'This is your public key. Others use it to send you encrypted messages. You can share it via QR code.',
            isPublicKey: true,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, String title, String subtitle,
      IconData icon, String tooltip,
      {bool isPublicKey = false}) {
    return Card(
      color: AppTheme.primary,
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        leading: Icon(icon, color: AppTheme.icon, size: 28),
        title: Text(title,
            style:
                const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
        subtitle: Text(
          subtitle,
          style:
              const TextStyle(color: AppTheme.text, fontSize: 16, height: 1.4),
          maxLines: isPublicKey ? 3 : 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          icon: const Icon(Icons.copy_outlined, color: AppTheme.icon, size: 20),
          tooltip: 'Copy to clipboard',
          onPressed: () {
            if (subtitle != 'Loading...') {
              Clipboard.setData(ClipboardData(text: subtitle));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$title copied to clipboard!')),
              );
            }
          },
        ),
      ),
    );
  }
}
