/// Presentation data for a lobby member. Populate from membership/profile streams
/// when lobby sync is integrated. Null rating/mic state means unknown.
class LobbyMember {
  const LobbyMember({
    required this.uid,
    required this.name,
    this.rank,
    this.rating,
    this.micEnabled,
  });
  final String uid, name;
  final String? rank;
  final double? rating;
  final bool? micEnabled;
}
