import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/rating_provider.dart';
import '../../chat/widgets/chat_widgets.dart';
import '../models/teammate_rating.dart';

class RateTeammateScreen extends ConsumerStatefulWidget {
  const RateTeammateScreen({
    super.key,
    required this.partyId,
    required this.targetUid,
  });
  final String partyId, targetUid;
  @override
  ConsumerState<RateTeammateScreen> createState() => _RateTeammateScreenState();
}

class _RateTeammateScreenState extends ConsumerState<RateTeammateScreen> {
  int _stars = 0;
  final _tags = <String>{};
  final _comment = TextEditingController();
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final uid = ref.read(authStateProvider).asData?.value?.uid;
    if (_saving || _stars == 0 || uid == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(ratingServiceProvider)
          .submit(
            widget.partyId,
            uid,
            widget.targetUid,
            RatingDraft(
              stars: _stars,
              tags: _tags.toList(),
              comment: _comment.text,
            ),
          );
      ref.invalidate(ratingCandidatesProvider(widget.partyId));
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is StateError
              ? error.message.toString()
              : error is FirebaseException && error.code == 'permission-denied'
              ? 'This review is no longer eligible or has already been submitted. Return to your teammates and refresh.'
              : 'Could not submit your review. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name =
        ref
            .watch(playerProfileProvider(widget.targetUid))
            .asData
            ?.value
            ?.username ??
        'Teammate';
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Rate Your Teammate'),
          actions: [
            IconButton(
              tooltip: 'Close rating',
              onPressed: _saving ? null : () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                Center(
                  child: SizedBox(
                    width: 88,
                    height: 88,
                    child: FittedBox(child: ChatAvatar(name: name)),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  'How was your game with $name?',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var star = 1; star <= 5; star++)
                      Flexible(
                        child: IconButton(
                          tooltip: '$star ${star == 1 ? 'star' : 'stars'}',
                          isSelected: _stars >= star,
                          onPressed: _saving
                              ? null
                              : () => setState(() => _stars = star),
                          icon: const Icon(Icons.star_border_rounded),
                          selectedIcon: const Icon(Icons.star_rounded),
                          iconSize: 34,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final tag in ratingTags)
                      FilterChip(
                        label: Text(tag),
                        selected: _tags.contains(tag),
                        onSelected: _saving
                            ? null
                            : (selected) => setState(() {
                                if (selected) {
                                  _tags.add(tag);
                                } else {
                                  _tags.remove(tag);
                                }
                              }),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _comment,
                  enabled: !_saving,
                  minLines: 3,
                  maxLines: 5,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    hintText: 'Add a comment (optional)',
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _saving || _stars == 0 ? null : _submit,
                  child: Text(_saving ? 'Submitting…' : 'Submit'),
                ),
                const SizedBox(height: 12),
                Text(
                  'Rate your experience playing together. You can submit one review per teammate for this party.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
