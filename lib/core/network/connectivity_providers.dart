import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Señal de conectividad (no garantiza de que Firestore responda).
final connectivityListProvider = StreamProvider<List<ConnectivityResult>>((
  ref,
) {
  return Connectivity().onConnectivityChanged;
});

final isOnlineProvider = Provider<bool>((ref) {
  final async = ref.watch(connectivityListProvider);
  return async.maybeWhen(
    data: (results) =>
        results.isNotEmpty && !results.every((r) => r == ConnectivityResult.none),
    orElse: () => true, // asumir online hasta el primer valor
  );
});
