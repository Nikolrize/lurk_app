class VoiceActivityTracker {
  VoiceActivityTracker({this.hold = const Duration(milliseconds: 700)});
  final Duration hold;
  final _lastHeard = <int, DateTime>{};

  // update only the speakers in this batch so other speakers are not cleared
  void update(Map<int, int> levels, DateTime now) {
    for (final entry in levels.entries) {
      if (entry.value > 10) {
        _lastHeard[entry.key] = now;
      } else {
        _lastHeard.remove(entry.key);
      }
    }
  }

  // remove speaking indicators when audio updates have stopped arriving
  Set<int> activeAt(DateTime now) {
    _lastHeard.removeWhere((_, heard) => now.difference(heard) >= hold);
    return Set.unmodifiable(_lastHeard.keys);
  }

  void remove(int uid) => _lastHeard.remove(uid);
  void clear() => _lastHeard.clear();
}
