import 'package:lurk_app/providers/voice_provider.dart';
import 'package:lurk_app/services/party_voice_service.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lurk_app/core/theme/app_theme.dart';
import 'package:lurk_app/core/widgets/app_shell.dart';
import 'package:lurk_app/features/parties/models/party.dart';
import 'package:lurk_app/features/parties/models/lobby_member.dart';
import 'package:lurk_app/features/parties/screens/party_lobby_screen.dart';
import 'package:lurk_app/models/player_profile.dart';
import 'package:lurk_app/services/party_service.dart';

import 'package:lurk_app/providers/auth_provider.dart';
import 'package:lurk_app/providers/party_provider.dart';
import 'package:lurk_app/providers/player_provider.dart';
import 'package:lurk_app/providers/profile_provider.dart';

class LobbyVoiceService extends PartyVoiceService {
  final events = StreamController<VoiceState>.broadcast();
  int connections = 0, toggles = 0;
  @override
  bool get configured => true;
  @override
  Stream<VoiceState> get changes => events.stream;
  @override
  Future<void> connect(String partyId) async {
    connections++;
    state = VoiceState(partyId: partyId, connected: true, muted: true);
    events.add(state);
  }

  @override
  Future<void> toggle(String partyId) async {
    toggles++;
    state = VoiceState(partyId: partyId, connected: true, muted: !state.muted);
    events.add(state);
  }

  @override
  Future<void> dispose() async {
    await events.close();
    await super.dispose();
  }
}

class LobbyPartyService extends Fake implements PartyService {
  int leaves = 0;
  int removals = 0;
  String? removedUid;
  @override
  Future<void> removeMember(
    String id,
    String memberUid, {
    required String expectedUid,
  }) async {
    removals++;
    removedUid = memberUid;
  }

  @override
  Future<void> leaveParty(String id, {required String expectedUid}) async {
    leaves++;
  }
}

const party = Party(
  id: 'party',
  hostId: 'host',
  title: 'Ranked squad',
  gameName: 'Valorant',
  playStyle: 'Competitive',
  currentPlayers: 3,
  maxPlayers: 5,
  visibility: 'private',
);
const members = [
  LobbyMember(
    uid: 'host',
    name: 'Nicole',
    rank: 'Platinum',
    rating: 4.9,
    micEnabled: true,
  ),
  LobbyMember(
    uid: 'alex',
    name: 'Alex',
    rank: 'Diamond',
    rating: 4.8,
    micEnabled: false,
  ),
  LobbyMember(
    uid: 'jay',
    name: 'Jay',
    rank: 'Ascendant',
    rating: 4.7,
    micEnabled: false,
  ),
];
void main() {
  for (final viewer in ['host', 'alex']) {
    testWidgets('Lobby auto-connects muted and restricts invites for $viewer', (
      tester,
    ) async {
      final voice = LobbyVoiceService();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            partyVoiceServiceProvider.overrideWithValue(voice),
            partyByIdProvider(
              'party',
            ).overrideWith((ref) => Stream.value(party)),
            myPartyMembershipProvider('party').overrideWith(
              (ref) => Stream.value({'leftAt': null, 'role': 'member'}),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.dark,
            home: Scaffold(
              body: PartyLobbyScreen(
                party: party,
                viewerUid: viewer,
                members: members,
                onBack: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(voice.connections, 1);
      expect(voice.state.muted, isTrue);
      expect(voice.toggles, 0);
      if (viewer == 'host') {
        await tester.scrollUntilVisible(
          find.text('Invite player'),
          100,
          scrollable: find.byType(Scrollable).first,
        );
        expect(
          tester
              .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, 'Invite player'),
              )
              .onPressed,
          isNotNull,
        );
      } else {
        expect(find.text('Invite player'), findsNothing);
      }
      await tester.tap(find.text('Mic: OFF'));
      await tester.pumpAndSettle();
      expect(voice.connections, 1);
      expect(voice.toggles, 1);
      expect(find.text('Mic: ON'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await voice.dispose();
    });
  }

  testWidgets(
    'Lobby shows roster and controls on a narrow phone without fake actions',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            partyByIdProvider(
              'party',
            ).overrideWith((ref) => Stream.value(party)),
          ],
          child: MaterialApp(
            theme: AppTheme.dark,
            home: Scaffold(
              body: PartyLobbyScreen(
                party: party,
                members: members,
                onBack: () {},
              ),
            ),
          ),
        ),
      );
      expect(find.text('Valorant party'), findsOneWidget);
      expect(find.text('3 / 5 players · Private party'), findsOneWidget);
      expect(find.text('Nicole · Platinum'), findsOneWidget);
      expect(find.byTooltip('Party host'), findsOneWidget);
      final controlPosition = tester.getTopLeft(find.text('Leave Party'));
      await tester.drag(find.byType(ListView).first, const Offset(0, -350));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('Leave Party')), controlPosition);
      expect(find.text('Mic: OFF').hitTestable(), findsOneWidget);
      expect(find.text('Chat').hitTestable(), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Leave Party'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Mic: OFF'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Join voice'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Voice chat is not configured. Run with config/voice.local.json.',
        ),
        findsOneWidget,
      );
      expect(find.text('Mic: ON'), findsNothing);
      ScaffoldMessenger.of(
        tester.element(find.text('Mic: OFF')),
      ).hideCurrentSnackBar();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leave Party'));
      await tester.pumpAndSettle();
      expect(find.text('Sign in to leave this party.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Shell opens the lobby with bottom navigation and back returns to Parties',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            partyByIdProvider(
              'party',
            ).overrideWith((ref) => Stream.value(party)),
            authStateProvider.overrideWith((ref) => Stream.value(null)),
            availablePartiesProvider.overrideWith((ref) => Stream.value([])),
            discoverablePlayersProvider.overrideWith((ref) => Stream.value([])),
            currentHostedPartyProvider.overrideWith(
              (ref) => Stream.value(party),
            ),
            playerProfileProvider('host').overrideWith(
              (ref) => Stream.value(
                const PlayerProfile(
                  uid: 'host',
                  username: 'Real host',
                  bio: '',
                  region: 'Asia',
                  createdAt: null,
                  updatedAt: null,
                ),
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.dark,
            home: const AppShell(uid: 'host'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Parties'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Back to Current Party'));
      await tester.pumpAndSettle();
      expect(find.text('Valorant party'), findsOneWidget);
      expect(find.text('Real host'), findsOneWidget);
      expect(find.text('Not rated'), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(
        tester.getBottomLeft(find.text('Leave Party')).dy,
        lessThan(tester.getTopLeft(find.byType(NavigationBar)).dy),
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Create Party'), findsOneWidget);
      expect(find.text('Valorant party'), findsNothing);
    },
  );
  testWidgets(
    'Leave confirmation calls supplied action only after confirmation',
    (tester) async {
      final service = LobbyPartyService();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            partyByIdProvider(
              'party',
            ).overrideWith((ref) => Stream.value(party)),
            partyServiceProvider.overrideWithValue(service),
          ],
          child: MaterialApp(
            theme: AppTheme.dark,
            home: Scaffold(
              body: PartyLobbyScreen(
                party: party,
                members: const [],
                onBack: () {},
                viewerUid: 'host',
              ),
            ),
          ),
        ),
      );
      await tester.ensureVisible(find.text('Leave Party'));
      await tester.tap(find.text('Leave Party'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(service.leaves, 0);
      await tester.tap(find.text('Leave Party'));
      await tester.pumpAndSettle();
      expect(find.text('End party session?'), findsOneWidget);
      expect(
        find.textContaining('party session will end for everyone'),
        findsOneWidget,
      );
      await tester.tap(find.text('End Session & Leave'));
      await tester.pumpAndSettle();
      expect(service.leaves, 1);
    },
  );

  testWidgets('Host removes a live member only after confirmation', (
    tester,
  ) async {
    final service = LobbyPartyService();
    final voice = StreamController<VoiceState>();
    addTearDown(voice.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          voiceStateProvider.overrideWith((ref) => voice.stream),
          partyByIdProvider('party').overrideWith((ref) => Stream.value(party)),
          partyMemberIdsProvider(
            'party',
          ).overrideWith((ref) => Stream.value(['host', 'alex'])),
          partyServiceProvider.overrideWithValue(service),
          playerProfileProvider.overrideWith(
            (ref, uid) => Stream.value(
              PlayerProfile(
                uid: uid,
                username: uid == 'host' ? 'Nicole' : 'Alex',
                bio: '',
                region: 'Asia',
                createdAt: null,
                updatedAt: null,
              ),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: PartyLobbyScreen(
              party: party,
              viewerUid: 'host',
              onBack: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    voice.add(
      const VoiceState(
        partyId: 'party',
        connected: true,
        remoteCount: 1,
        remoteMics: {'alex': true},
        speakingPlayers: {'alex'},
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Unmuted'), findsOneWidget);
    final activeCard = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('voice-card-alex')),
    );
    expect((activeCard.decoration! as BoxDecoration).boxShadow, isNotEmpty);
    voice.add(
      const VoiceState(
        partyId: 'party',
        connected: true,
        remoteCount: 1,
        remoteMics: {'alex': true},
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Unmuted'), findsOneWidget);
    final quietCard = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('voice-card-alex')),
    );
    expect((quietCard.decoration! as BoxDecoration).boxShadow, isEmpty);
    expect(find.textContaining('1 others in voice'), findsOneWidget);
    voice.add(
      const VoiceState(
        partyId: 'party',
        connected: true,
        remoteCount: 1,
        remoteMics: {'alex': false},
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Unmuted'), findsNothing);
    expect(find.byTooltip('Muted'), findsNWidgets(2));
    await tester.tap(find.byTooltip('Options for Nicole'));
    await tester.pumpAndSettle();
    expect(find.text('Remove player'), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Options for Alex'));
    await tester.ensureVisible(find.byTooltip('Options for Alex'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Options for Alex'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove player'));
    await tester.pumpAndSettle();
    expect(find.text('Remove player?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(service.removals, 0);
    await tester.ensureVisible(find.byTooltip('Options for Alex'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Options for Alex'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove player'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(service.removals, 1);
    expect(service.removedUid, 'alex');
  });
  testWidgets('A removed player loses lobby controls immediately', (
    tester,
  ) async {
    final membership = StreamController<Map<String, dynamic>?>();
    addTearDown(membership.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          partyByIdProvider('party').overrideWith((ref) => Stream.value(party)),
          myPartyMembershipProvider(
            'party',
          ).overrideWith((ref) => membership.stream),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: PartyLobbyScreen(
              party: party,
              viewerUid: 'alex',
              members: const [],
              onBack: () {},
            ),
          ),
        ),
      ),
    );
    membership.add({'role': 'member', 'leftAt': null});
    await tester.pumpAndSettle();
    expect(find.text('Leave Party'), findsOneWidget);
    membership.add({
      'role': 'member',
      'leftAt': DateTime.now(),
      'removedBy': 'host',
    });
    await tester.pumpAndSettle();
    expect(find.text('You were removed from this party.'), findsOneWidget);
    expect(find.text('Leave Party'), findsNothing);
    expect(find.text('Back to Parties'), findsOneWidget);
  });
}
