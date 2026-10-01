import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import 'emulator_config.dart';

/// Callable Functions. Solo acciones raras (admin / reprocess).
final firebaseFunctionsProvider = Provider<FirebaseFunctions>((ref) {
  final config = ref.watch(appConfigProvider);
  final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
  if (config.useEmulators) {
    functions.useFunctionsEmulator(EmulatorConfig.host(), 5001);
  }
  return functions;
});
