import 'package:flutter/material.dart';
import 'package:my_chatapp/core/theme.dart';

class FeaturesScreen extends StatelessWidget {
  const FeaturesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App Features'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: const [
          _FeatureCard(
            icon: Icons.lock_outline,
            title: 'End-to-End Encryption (E2EE)',
            description:
                'All your messages, files, and calls are secured with the Signal Protocol (X25519 and AES-GCM). Only you and the recipient can read them, no one in between, not even us.',
          ),
          _FeatureCard(
            icon: Icons.history_toggle_off,
            title: 'Ephemeral Messaging (No History)',
            description:
                'Your conversations are temporary. Messages are not stored on our servers or on your device after you close the chat, ensuring maximum privacy.',
          ),
          _FeatureCard(
            icon: Icons.mic_off_outlined,
            title: 'Secure Voice Calls',
            description:
                'Make crystal-clear voice calls that are also end-to-end encrypted. Your conversations are private and secure from eavesdropping.',
          ),
          _FeatureCard(
            icon: Icons.no_cell,
            title: 'No Phone Number Required',
            description:
                'Your identity is based on a cryptographic public key, not your phone number. This protects your real-world identity.',
          ),
          _FeatureCard(
            icon: Icons.cloud_off,
            title: 'Decentralized & Serverless',
            description:
                'The server only acts as a relay to connect users. It does not store any personal data, messages, or contact lists.',
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      color: AppTheme.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppTheme.accent, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: const TextStyle(
                fontSize: 15,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
