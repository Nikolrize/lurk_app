import '../widgets/party_preview_drawer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/party_provider.dart';
import '../models/party.dart';

class PartyJoinButton extends ConsumerStatefulWidget {
  const PartyJoinButton({
    super.key,
    required this.party,
    this.preview = true,
    this.disabled = false,
    this.onError,
  });
  final bool preview, disabled;
  final ValueChanged<String>? onError;
  final Party party;
  @override
  ConsumerState<PartyJoinButton> createState() => _PartyJoinButtonState();
}

class _PartyJoinButtonState extends ConsumerState<PartyJoinButton> {
  bool _joining = false;
  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authStateProvider).asData?.value?.uid;
    final joined = ref.watch(joinedPartyIdProvider).asData?.value;
    final membership = joined == widget.party.id
        ? ref.watch(myPartyMembershipProvider(widget.party.id)).asData?.value
        : null;
    final alreadyJoined =
        (uid != null && uid == widget.party.hostId) ||
        (joined == widget.party.id &&
            membership != null &&
            membership['leftAt'] == null);
    return FilledButton(
      onPressed:
          widget.disabled ||
              (widget.preview && uid != null && uid == widget.party.hostId) ||
              _joining ||
              (!widget.preview && widget.party.isFull && !alreadyJoined)
          ? null
          : () async {
              if (widget.preview) {
                setState(() => _joining = true);
                try {
                  await showPartyPreview(context, widget.party);
                } finally {
                  if (mounted) setState(() => _joining = false);
                }
                return;
              }
              widget.onError?.call('');
              setState(() => _joining = true);
              await joinPartyAndOpen(
                context,
                ref,
                widget.party,
                onError: widget.onError,
              );
              if (mounted) setState(() => _joining = false);
            },
      child: Text(
        widget.preview
            ? 'Join'
            : _joining
            ? 'Joining…'
            : widget.party.isFull && !alreadyJoined
            ? 'Party Full'
            : 'Join Party',
      ),
    );
  }
}

Future<void> joinPartyAndOpen(
  BuildContext context,
  WidgetRef ref,
  Party party, {
  ValueChanged<String>? onError,
}) async {
  final uid = ref.read(authStateProvider).asData?.value?.uid;
  if (uid == null) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Sign in to join a party.')));
    return;
  }
  try {
    await ref.read(partyServiceProvider).joinParty(party.id, expectedUid: uid);
    if (!context.mounted) return;
    ref.read(lobbyNavigationProvider.notifier).open(party);
    Navigator.of(context).popUntil((route) => route.isFirst);
  } catch (error) {
    if (!context.mounted) return;
    final message = error is StateError
        ? error.message.toString()
        : error is FirebaseException && error.code == 'permission-denied'
        ? 'Unable to join. You may need an invitation, or this party is no longer available.'
        : 'Unable to join the party. Check your connection and try again.';
    if (onError != null) {
      onError(message);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }
}
