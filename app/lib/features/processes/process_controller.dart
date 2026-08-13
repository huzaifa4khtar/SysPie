import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models/process_model.dart';
import '../../core/syspie_client.dart';

final sysPieClientProvider = Provider<SysPieClient>((ref) {
  throw StateError(
    'sysPieClientProvider must be overridden in main(). '
    'Call ProviderScope(overrides: [sysPieClientProvider.overrideWithValue(client)])',
  );
});

class ProcessState {
  final List<ProcessModel> processes;
  final bool isLoading;
  final String? error;

  const ProcessState({
    this.processes = const [],
    this.isLoading = false,
    this.error,
  });

  ProcessState copyWith({
    List<ProcessModel>? processes,
    bool? isLoading,
    String? error,
  }) {
    return ProcessState(
      processes: processes ?? this.processes,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class ProcessNotifier extends Notifier<ProcessState> {
  StreamSubscription<Map<String, dynamic>>? _subscription;

  @override
  ProcessState build() {
    _subscription = ref.read(sysPieClientProvider).events.listen((event) {
      final type = event['type'] as String?;
      if (type == 'processes') {
        final data = event['data'] as List<dynamic>;
        final processes =
            data.map((item) => ProcessModel.fromJson(item)).toList();
        state = state.copyWith(
          processes: processes,
          isLoading: false,
          error: null,
        );
      } else if (type == 'processes_diff') {
        _applyProcessDiff(event);
      }
    });

    ref.onDispose(() => _subscription?.cancel());
    return const ProcessState();
  }

  void _applyProcessDiff(Map<String, dynamic> event) {
    final current = Map<int, ProcessModel>.fromEntries(
      state.processes.map((p) => MapEntry(p.pid, p)),
    );

    if (event['added'] is List) {
      for (final item in event['added'] as List) {
        final p = ProcessModel.fromJson(
            item is Map ? item as Map<String, dynamic> : {});
        current[p.pid] = p;
      }
    }
    if (event['updated'] is List) {
      for (final item in event['updated'] as List) {
        final p = ProcessModel.fromJson(
            item is Map ? item as Map<String, dynamic> : {});
        current[p.pid] = p;
      }
    }
    if (event['removed'] is List) {
      for (final pid in event['removed'] as List) {
        if (pid is int) current.remove(pid);
      }
    }

    state = state.copyWith(
      processes: current.values.toList(),
      isLoading: false,
    );
  }
}

final processProvider =
    NotifierProvider<ProcessNotifier, ProcessState>(ProcessNotifier.new);
