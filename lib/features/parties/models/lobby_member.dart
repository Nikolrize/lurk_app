/// Presentation data for a lobby member. Populate from membership/profile streams
/// when lobby sync is integrated. Null rating/mic state means unknown.
class LobbyMember {
  const LobbyMember({
    required this.uid,
    required this.name,
    this.rank,
    this.photoPath,
    this.rating,
    this.ratingLabel,
    this.micEnabled,
    this.isSpeaking = false,
  });
  final String uid, name;
  final String? rank;
  final String? photoPath;
  final double? rating;
  final String? ratingLabel;
  final bool? micEnabled;
  final bool isSpeaking;
}
