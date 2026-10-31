import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});
  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _saving = false;
  late final DocumentReference<Map<String, dynamic>> _preferences;
  late Stream<DocumentSnapshot<Map<String, dynamic>>> _stream;
  @override
  void initState() {
    super.initState();
    _preferences = FirebaseFirestore.instance
        .collection('notification_preferences')
        .doc(FirebaseAuth.instance.currentUser!.uid);
    _stream = _preferences.snapshots();
  }

  Future<void> _save(
    Map<String, dynamic> current,
    String key,
    bool enabled,
  ) async {
    setState(() => _saving = true);
    try {
      await _preferences.set({
        'messages': current['messages'] != false,
        'invitations': current['invitations'] != false,
        key: enabled,
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save your settings. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Settings')),
    body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Unable to load settings.'),
                TextButton(
                  onPressed: () => setState(() {
                    _stream = _preferences.snapshots();
                  }),
                  child: const Text('Try again'),
                ),
              ],
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!.data() ?? {};
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Notifications',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Chat messages'),
                    subtitle: const Text(
                      'Get notified when a player messages you.',
                    ),
                    value: data['messages'] != false,
                    onChanged: _saving
                        ? null
                        : (value) => _save(data, 'messages', value),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('Party invitations'),
                    subtitle: const Text(
                      'Get notified when you are invited to a party.',
                    ),
                    value: data['invitations'] != false,
                    onChanged: _saving
                        ? null
                        : (value) => _save(data, 'invitations', value),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Allow notifications for Lurk in your phone settings to receive push alerts. These preferences apply to your account across devices.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        );
      },
    ),
  );
}
