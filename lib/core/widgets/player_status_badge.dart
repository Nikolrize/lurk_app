import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lurk_app/models/player_status.dart';
import 'package:lurk_app/providers/auth_provider.dart';
import 'package:lurk_app/providers/presence_provider.dart';

class PlayerStatusBadge extends ConsumerStatefulWidget {
  const PlayerStatusBadge({
    super.key,
    required this.uid,
    this.editable = false,
  });

  final String uid;
  final bool editable;

  @override
  ConsumerState<PlayerStatusBadge> createState() =>
      _PlayerStatusBadgeState();
}

class _PlayerStatusBadgeState
    extends ConsumerState<PlayerStatusBadge> {
  bool _saving = false;

  Color _colorFor(PlayerStatus? status) {
    return switch (status) {
      PlayerStatus.online => const Color(0xFF22C55E),
      PlayerStatus.idle => const Color(0xFFF59E0B),
      PlayerStatus.doNotDisturb => const Color(0xFFEF4444),
      PlayerStatus.offline || null => const Color(0xFF9CA3AF),
    };
  }

  IconData _iconFor(PlayerStatus? status) {
    return switch (status) {
      PlayerStatus.online => Icons.circle,
      PlayerStatus.idle => Icons.bedtime,
      PlayerStatus.doNotDisturb => Icons.do_not_disturb_on,
      PlayerStatus.offline => Icons.circle_outlined,
      null => Icons.help_outline,
    };
  }

  Future<void> _selectStatus(PlayerStatus status) async {
    if (_saving) return;

    setState(() {
      _saving = true;
    });

    try {
      await ref.read(presenceServiceProvider).setPreference(
        expectedUid: widget.uid,
        status: status,
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to update status. Check your connection and try again.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playerPresenceProvider(widget.uid));
    final currentUid =
        ref.watch(authStateProvider).asData?.value?.uid;

    final canEdit = widget.editable && currentUid == widget.uid;

    final connected = canEdit ? ref.watch(presenceConnectionProvider).asData?.value == true : true;

    final presence = state.asData?.value;

    final status = canEdit && !connected ? PlayerStatus.offline : presence?.effectiveStatus; //never displays online when preference is offline

    final label = state.isLoading
        ? 'Checking status...'
        : state.hasError
            ? 'Status unavailable'
            : status == PlayerStatus.offline
                ? 'Offline'
                : status?.label ?? 'Status unavailable';

    final badge = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: canEdit ? 10 : 0,
        vertical: 8,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _iconFor(status),
            color: _colorFor(status),
            size: 14,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          if (canEdit) ...[
            const SizedBox(width: 4),
            if (_saving)
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              const Icon(Icons.expand_more, size: 18),
          ],
        ],
      ),
    );

    if (!canEdit) {
      return Align(
        alignment: Alignment.centerLeft,
        child: badge,
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: PopupMenuButton<PlayerStatus>(
        tooltip: presence == null ? 'Choose status' : 'Selected: ${presence.preference.label}',
        initialValue: presence?.preference,
        enabled: connected && presence != null && !_saving,
        onSelected: _selectStatus,
        itemBuilder: (context) => [
          for (final option in PlayerStatus.values)
            PopupMenuItem(
              value: option,
              child: Row(
                children: [
                  Icon(
                    _iconFor(option),
                    color: _colorFor(option),
                    size: 18,
                  ),
                  const SizedBox(width: 12),
                  Text(option.label),
                ],
              ),
            ),
        ],
        child: badge,
      ),
    );
  }
}