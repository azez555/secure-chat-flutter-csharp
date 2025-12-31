import 'package:flutter/material.dart';
import 'package:my_chatapp/core/theme.dart';
import 'package:my_chatapp/screens/add_contact_screen.dart';
import 'package:my_chatapp/screens/conversation_screen.dart';
import 'package:my_chatapp/services/contact_service.dart';
import 'package:my_chatapp/widgets/main_drawer.dart';
import 'package:provider/provider.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  late Future<List<Contact>> _contactsFuture;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  void _loadContacts() {
    final contactService = Provider.of<ContactService>(context, listen: false);
    setState(() {
      _contactsFuture = contactService.getContacts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Secure Chat'),
        actions: [],
      ),
      drawer: const MainDrawer(),
      body: FutureBuilder<List<Contact>>(
        future: _contactsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'You have no contacts yet.\nTap the + button to add one.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
              ),
            );
          }
          final contacts = snapshot.data!;
          return ListView.separated(
            itemCount: contacts.length,
            separatorBuilder: (context, index) =>
                const Divider(indent: 80, height: 1),
            itemBuilder: (ctx, index) {
              final contact = contacts[index];
              return ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                leading: CircleAvatar(
                  radius: 28,
                  backgroundColor: AppTheme.accent,
                  child: Text(
                    contact.name.isNotEmpty
                        ? contact.name.substring(0, 1).toUpperCase()
                        : '?',
                    style: const TextStyle(
                        fontSize: 24,
                        color: Colors.white,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(contact.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w500, fontSize: 17)),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ConversationScreen(contact: contact),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add_comment_rounded, size: 28),
        onPressed: () async {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (context) => const AddContactScreen()),
          );
          if (result == true && mounted) {
            _loadContacts();
          }
        },
      ),
    );
  }
}
