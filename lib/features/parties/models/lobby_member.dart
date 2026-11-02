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
