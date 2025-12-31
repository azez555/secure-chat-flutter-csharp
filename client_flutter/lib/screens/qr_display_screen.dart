import 'package:flutter/material.dart';
import 'package:my_chatapp/core/theme.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QrDisplayScreen extends StatelessWidget {
  final String data;
  const QrDisplayScreen({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Me'),
      ),
      backgroundColor: AppTheme.chatBackground,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: QrImageView(
                data: data,
                version: QrVersions.auto,
                size: 250.0,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Ask your contact to scan this code',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
