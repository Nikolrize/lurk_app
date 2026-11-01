import 'package:flutter_riverpod/flutter_riverpod.dart';

class DiscoveryLimit extends Notifier<int> {
  @override
  int build() => 100;
  void loadMore() => state += 100;
}

class HistoryLimit extends Notifier<int> {
  @override
  int build() => 50;
  void loadMore() => state += 50;
}

final partyDiscoveryLimitProvider = NotifierProvider<DiscoveryLimit, int>(
  DiscoveryLimit.new,
);
final playerDiscoveryLimitProvider = NotifierProvider<DiscoveryLimit, int>(
  DiscoveryLimit.new,
);
final historyLimitProvider = NotifierProvider<HistoryLimit, int>(
  HistoryLimit.new,
);
