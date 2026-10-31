import '../../../providers/chat_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/profile_provider.dart';
import '../../../services/player_safety_service.dart';

class ReportPlayerScreen extends ConsumerStatefulWidget {
  const ReportPlayerScreen({super.key, required this.uid});
  final String uid;
  @override
  ConsumerState<ReportPlayerScreen> createState() => _ReportPlayerScreenState();
}

class _ReportPlayerScreenState extends ConsumerState<ReportPlayerScreen> {
  final _details = TextEditingController();
  final Set<String> _reasons = {};
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (_reasons.isEmpty) {
      setState(() => _error = 'Select at least one reason.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(playerSafetyServiceProvider)
          .report(widget.uid, _reasons.toList(), _details.text);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report submitted. Thank you for letting us know.'),
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Unable to submit report. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name =
        ref.watch(playerProfileProvider(widget.uid)).asData?.value?.username ??
        'Player';
    return Scaffold(
      appBar: AppBar(title: const Text('Report Player')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  radius: 28,
                  child: Icon(Icons.person_outline),
                ),
                title: Text(name),
                subtitle: Text(
                  ref
                          .watch(chatPlayerProvider(widget.uid))
                          .asData
                          ?.value
                          ?.currentGame ??
                      'Game not shared',
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Reasons for report (select all that apply)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    for (final reason in reportReasons)
                      CheckboxListTile(
                        value: _reasons.contains(reason),
                        title: Text(reason),
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged: _saving
                            ? null
                            : (selected) => setState(() {
                                if (selected == true) {
                                  _reasons.add(reason);
                                } else {
                                  _reasons.remove(reason);
                                }
                                _error = null;
                              }),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Additional details (optional)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _details,
                enabled: !_saving,
                maxLength: 2000,
                minLines: 4,
                maxLines: 7,
                decoration: const InputDecoration(
                  hintText: 'Tell us more about what happened...',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _submit,
                child: Text(_saving ? 'Submitting...' : 'Submit'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
