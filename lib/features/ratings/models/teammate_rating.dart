const ratingTags = ['Good communication', 'Team player', 'Friendly', 'Skilled'];

class RatingDraft {
  const RatingDraft({
    required this.stars,
    this.tags = const [],
    this.comment = '',
  });
  final int stars;
  final List<String> tags;
  final String comment;
  void validate() {
    if (stars < 1 ||
        stars > 5 ||
        comment.trim().length > 500 ||
        tags.toSet().length != tags.length ||
        tags.any((tag) => !ratingTags.contains(tag))) {
      throw ArgumentError(
        'Choose 1–5 stars and valid feedback (up to 500 characters).',
      );
    }
  }
}

class RatingSummary {
  const RatingSummary({this.total = 0, this.count = 0});
  final int total, count;
  double get average => count == 0 ? 0 : total / count;
}

class RatingCandidate {
  const RatingCandidate(this.uid, {this.rated = false});
  final String uid;
  final bool rated;
}
