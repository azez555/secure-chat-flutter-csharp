import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import 'package:my_chatapp/core/theme.dart';
import 'package:my_chatapp/screens/qr_scanner_screen.dart';
import 'package:my_chatapp/services/contact_service.dart';

class AddContactScreen extends StatefulWidget {
  const AddContactScreen({super.key});

  @override
  State<AddContactScreen> createState() => _AddContactScreenState();
}

class _AddContactScreenState extends State<AddContactScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _publicKeyController = TextEditingController();

  String? _fingerprint;
  bool _keyPasted = false;

  void _pasteKey() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboardData != null && clipboardData.text != null) {
      setState(() {
        _publicKeyController.text = clipboardData.text!;
        _updateFingerprint();
      });
    }
  }

  void _scanKey() async {
    final scannedKey = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const QRScannerScreen()),
    );
    if (scannedKey != null && mounted) {
      setState(() {
        _publicKeyController.text = scannedKey;
        _updateFingerprint();
      });
    }
  }

  void _updateFingerprint() async {
    final key = _publicKeyController.text.trim();
    if (key.isNotEmpty) {
      try {
        setState(() {
          _fingerprint = 'Key ready to be saved.';
          _keyPasted = true;
        });
      } catch (e) {
        setState(() {
          _fingerprint = 'Invalid Public Key';
          _keyPasted = true;
        });
      }
    } else {
      setState(() {
        _keyPasted = false;
        _fingerprint = null;
      });
    }
  }

  Future<void> _saveContact() async {
    if (_formKey.currentState!.validate()) {
      final contactService = ContactService();
      try {
        final newContact = Contact(
          name: _nameController.text.trim(),
          publicKey: _publicKeyController.text.trim(),
        );
        await contactService.addContact(newContact);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Contact saved successfully!'),
                backgroundColor: Colors.green),
          );
          Navigator.of(context).pop(true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Error saving contact: $e'),
                backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add New Contact')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: _keyPasted ? _buildSaveForm() : _buildInitialView(),
      ),
    );
  }

  Widget _buildInitialView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        const Icon(Iconsax.user_add, size: 80, color: AppTheme.accent),
        const SizedBox(height: 20),
        const Text('Add Contact via QR Code or Public Key',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
        const SizedBox(height: 12),
        const Text(
            'For maximum security, scan the QR code directly from your contact\'s device.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
        const SizedBox(height: 40),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12))),
          onPressed: _scanKey,
          icon: const Icon(Iconsax.scan_barcode),
          label: const Text('SCAN QR CODE', style: TextStyle(fontSize: 16)),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.accent,
              side: const BorderSide(color: AppTheme.accent),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12))),
          onPressed: _pasteKey,
          icon: const Icon(Iconsax.document_copy),
          label: const Text('PASTE PUBLIC KEY', style: TextStyle(fontSize: 16)),
        ),
      ],
    );
  }

  Widget _buildSaveForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('VERIFY & SAVE',
              style: TextStyle(
                  color: AppTheme.accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
          const SizedBox(height: 16),
          Card(
            color: AppTheme.primary,
            child: ListTile(
              leading: const Icon(Iconsax.key, color: AppTheme.icon),
              title: const Text('Public Key',
                  style: TextStyle(color: AppTheme.textSecondary)),
              subtitle: Text(
                _publicKeyController.text,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.normal),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
                labelText: 'Contact Name',
                prefixIcon: Icon(Iconsax.user),
                border: OutlineInputBorder()),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a name for the contact.';
              }
              return null;
            },
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white),
            onPressed:
                _fingerprint == 'Invalid Public Key' ? null : _saveContact,
            child: const Text('SAVE CONTACT'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              setState(() {
                _keyPasted = false;
                _publicKeyController.clear();
                _fingerprint = null;
              });
            },
            child: const Text('<- Back to Scan/Paste'),
          ),
        ],
      ),
    );
  }
}
