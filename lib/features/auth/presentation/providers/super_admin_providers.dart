import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import 'auth_providers.dart';

/// Bootstrap temporal por email hasta asignar Custom Claim `superAdmin`.
/// Preferir claim; este allowlist solo cubre la cuenta operativa inicial.
const kBootstrapSuperAdminEmails = {
  'administracion@tinguar.com',
};

/// `true` / `false` / `null` (cargando).
final isSuperAdminProvider = FutureProvider<bool>((ref) async {
  if (ref.watch(appConfigProvider).backendMode == BackendMode.local) {
    return false;
  }
  // Re-evaluar al cambiar la sesion.
  final authUser = ref.watch(authStateProvider).asData?.value;
  if (authUser == null) return false;
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return false;
  final token = await user.getIdTokenResult(true);
  if (token.claims?['superAdmin'] == true) return true;
  final email = user.email?.trim().toLowerCase();
  return email != null && kBootstrapSuperAdminEmails.contains(email);
});

/// Lectura sync para el router (null = aun resolviendo).
final superAdminStatusProvider = Provider<bool?>((ref) {
  final async = ref.watch(isSuperAdminProvider);
  if (async.isLoading) return null;
  if (async.hasError) return false;
  return async.value ?? false;
});
