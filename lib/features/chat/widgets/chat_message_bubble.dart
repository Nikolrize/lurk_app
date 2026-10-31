import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../models/chat_message.dart';
import 'party_invite_card.dart';

class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.mine,
  });
  final ChatMessage message;
  final bool mine;
  @override
  Widget build(BuildContext context) => Align(
    alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * .76,
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: message.isPartyInvite && message.partyId != null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  PartyInviteCard(partyId: message.partyId!, sentByMe: mine),
                ],
              )
            : Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: mine ? AppColors.primary : AppColors.surface,
                  border: Border.all(
                    color: mine ? AppColors.primary : AppColors.outline,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [SelectableText(message.text)],
                ),
              ),
      ),
    ),
  );
}

String chatDateLabel(BuildContext context, DateTime date) {
  final local = date.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final label = day == today
      ? 'TODAY'
      : day == DateTime(now.year, now.month, now.day - 1)
      ? 'YESTERDAY'
      : MaterialLocalizations.of(context).formatMediumDate(local).toUpperCase();
  return '$label · ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
}
