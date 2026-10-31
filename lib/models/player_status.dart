//enum restircts to only four choices
enum PlayerStatus {
  online('online', 'Online'),
  idle('idle', 'Idle'),
  doNotDisturb('do_not_disturb', 'Do not disturb'),
  offline('offline', 'Appear offline');

  const PlayerStatus(this.id, this.label);

  final String id;
  final String label;

  static PlayerStatus? fromId(String? id) {
    for (final status in values) {
      if (status.id == id) {
        return status;
      }
    }

    return null;
  }
}