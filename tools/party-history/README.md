# Party history

- Open Parties → Party History. This view stays inside AppShell and keeps bottom navigation.
- Game filters use GameCatalog. Cards show the party title, game, mode, the player's session duration, and local end date/time.
- A session appears when the player leaves (including switching or being removed), or when its host closes it. Active sessions are excluded.
- Durations use membership joinedAt and leftAt; members still present at closure use the party completedAt timestamp, falling back to its closed updatedAt. Unknown timestamps are shown as unavailable.
- Private references live at players/{uid}/party_history/{partyId}, created atomically with hosting/joining. They contain title, gameId, mode, and joinedAt. They can only be read by that player. Verified participants with a history reference have read-only access to their past party details and participant list through the shared preview drawer. Outsiders still cannot read private parties or their rosters.
- The page loads the 50 most recently joined parties and sorts completed entries by end time. One reference exists per party; rejoining replaces it with the latest participation. Add pagination and separate visit IDs if every visit needs a distinct row.
- PartyHistoryScreen accepts onRate(PartyHistoryEntry). The rating feature can use entry.record.partyId and the authenticated player. Until connected, Rate is disabled and no fabricated Rated state is shown.

## Existing party migration

Run from the project root with a locally signed-in Firebase CLI administrator:

    node tools/party-history/backfill.cjs

The default is a read-only preview. To create missing references from existing party membership records:

    node tools/party-history/backfill.cjs --apply

This script uses the local Firebase CLI login, never prints credentials, skips existing references, and never deletes or replaces source party/member data. Records without a usable join time or party summary are skipped. It targets lurk-mae explicitly.