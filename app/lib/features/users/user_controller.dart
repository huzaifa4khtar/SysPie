import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../processes/process_controller.dart';

class UserState {
  final List<String> realUsers;
  final bool isLoading;
  final String? error;

  const UserState({
    this.realUsers = const [],
    this.isLoading = false,
    this.error,
  });

  UserState copyWith({
    List<String>? realUsers,
    bool? isLoading,
    String? error,
  }) {
    return UserState(
      realUsers: realUsers ?? this.realUsers,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class UserNotifier extends Notifier<UserState> {
  StreamSubscription<Map<String, dynamic>>? _subscription;

  @override
  UserState build() {
    _subscription = ref.read(sysPieClientProvider).events.listen((event) {
      final type = event['type'] as String?;
      if (type == 'users') {
        final data = event['data'] as List<dynamic>;
        final users = data.map((item) => item.toString()).toList();
        state = state.copyWith(
          realUsers: users,
          isLoading: false,
          error: null,
        );
      }
    });

    ref.onDispose(() => _subscription?.cancel());
    _requestUsers();
    return const UserState();
  }

  void _requestUsers() {
    ref.read(sysPieClientProvider).sendCommand({'cmd': 'list_users'});
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    _requestUsers();
  }
}

final userProvider =
    NotifierProvider<UserNotifier, UserState>(UserNotifier.new);
