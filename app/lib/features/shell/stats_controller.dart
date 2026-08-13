import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models/process_model.dart';
import '../processes/process_controller.dart';

class StatsState {
  final SystemStatsModel stats;
  final bool isLoading;
  final String? error;

  const StatsState({
    this.stats = const SystemStatsModel(
      cpuUsagePercent: 0,
      totalProcesses: 0,
      totalThreads: 0,
      totalHandles: 0,
      totalPhysicalMB: 0,
      usedPhysicalMB: 0,
      availablePhysicalMB: 0,
      commitChargeMB: 0,
      commitLimitMB: 0,
    ),
    this.isLoading = false,
    this.error,
  });

  StatsState copyWith({
    SystemStatsModel? stats,
    bool? isLoading,
    String? error,
  }) {
    return StatsState(
      stats: stats ?? this.stats,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class StatsNotifier extends Notifier<StatsState> {
  StreamSubscription<Map<String, dynamic>>? _subscription;

  @override
  StatsState build() {
    _subscription = ref.read(sysPieClientProvider).events.listen((event) {
      final type = event['type'] as String?;
      if (type == 'stats') {
        final data = event['data'] as Map<String, dynamic>;
        final stats = SystemStatsModel.fromJson(data);
        state = state.copyWith(
          stats: stats,
          isLoading: false,
          error: null,
        );
      }
    });

    ref.onDispose(() => _subscription?.cancel());
    return const StatsState();
  }
}

final statsProvider =
    NotifierProvider<StatsNotifier, StatsState>(StatsNotifier.new);
