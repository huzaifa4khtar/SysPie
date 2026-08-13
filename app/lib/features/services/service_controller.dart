import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'service_model.dart';
import '../processes/process_controller.dart';

class ServiceState {
  final List<ServiceModel> services;
  final bool isLoading;
  final String? error;

  const ServiceState({
    this.services = const [],
    this.isLoading = false,
    this.error,
  });

  ServiceState copyWith({
    List<ServiceModel>? services,
    bool? isLoading,
    String? error,
  }) {
    return ServiceState(
      services: services ?? this.services,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class ServiceNotifier extends Notifier<ServiceState> {
  StreamSubscription<Map<String, dynamic>>? _subscription;

  @override
  ServiceState build() {
    _subscription = ref.read(sysPieClientProvider).events.listen((event) {
      final type = event['type'] as String?;
      if (type == 'services') {
        final data = event['data'] as List<dynamic>;
        final services =
            data.map((item) => ServiceModel.fromJson(item)).toList();
        state = state.copyWith(
          services: services,
          isLoading: false,
          error: null,
        );
      }
    });

    ref.onDispose(() => _subscription?.cancel());
    _requestServices();
    return const ServiceState();
  }

  void _requestServices() {
    ref.read(sysPieClientProvider).sendCommand({'cmd': 'list_services'});
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    _requestServices();
  }
}

final serviceProvider =
    NotifierProvider<ServiceNotifier, ServiceState>(ServiceNotifier.new);
