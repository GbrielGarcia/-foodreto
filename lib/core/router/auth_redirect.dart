import 'app_routes.dart';

/// Estado del perfil del usuario autenticado, visto desde el router.
enum ProfileStatus {
  /// Aún no se sabe (cargando sesión o perfil).
  unknown,

  /// Hay sesión pero falta completar el perfil (@username).
  missing,
  complete,
}

/// Decide a dónde redirigir según el estado de sesión y de perfil.
///
/// [isSignedIn] es `null` mientras la sesión aún se está resolviendo.
/// [isSuperAdmin] es `null` mientras se resuelve el claim/allowlist.
/// El destino original se conserva en `?from=` para volver tras el login o el
/// onboarding (por ejemplo, un enlace de invitación `/join/AB12CD`).
String? authRedirect({
  required bool? isSignedIn,
  required Uri uri,
  ProfileStatus profile = ProfileStatus.complete,
  bool? isSuperAdmin,
}) {
  final path = uri.path;
  final isAuthRoute = AppRoutes.publicAuthRoutes.contains(path);
  final isSplash = path == AppRoutes.splash;
  final isOnboarding = path == AppRoutes.onboarding;
  final isAdminPath = path == AppRoutes.admin || path.startsWith('/admin/');
  final from = isAuthRoute || isSplash || isOnboarding
      ? sanitizeFrom(uri.queryParameters['from'])
      : _originalLocation(uri);

  if (isSignedIn == null) {
    return isSplash ? null : _withFrom(AppRoutes.splash, from);
  }

  if (!isSignedIn) {
    return isAuthRoute ? null : _withFrom(AppRoutes.login, from);
  }

  switch (profile) {
    case ProfileStatus.unknown:
      return isSplash ? null : _withFrom(AppRoutes.splash, from);
    case ProfileStatus.missing:
      return isOnboarding ? null : _withFrom(AppRoutes.onboarding, from);
    case ProfileStatus.complete:
      // Esperar claim/allowlist antes de decidir panel admin vs app.
      if ((isAuthRoute || isSplash || isOnboarding || isAdminPath) &&
          isSuperAdmin == null) {
        return isSplash ? null : _withFrom(AppRoutes.splash, from);
      }

      if (isAdminPath && isSuperAdmin == false) {
        return AppRoutes.home;
      }

      if (isAuthRoute || isSplash || isOnboarding) {
        if (isSuperAdmin == true) {
          if (from != null && from.startsWith('/admin')) return from;
          return AppRoutes.admin;
        }
        return from ?? AppRoutes.home;
      }

      // Tras login, Super Admin en la raíz del shell de usuario → panel admin.
      if (isSuperAdmin == true && path == AppRoutes.home) {
        return AppRoutes.admin;
      }
      return null;
  }
}

/// Solo acepta rutas internas para evitar redirecciones abiertas.
String? sanitizeFrom(String? from) {
  if (from == null || from.isEmpty) return null;
  if (!from.startsWith('/') || from.startsWith('//')) return null;
  final path = Uri.tryParse(from)?.path;
  if (path == null ||
      path == AppRoutes.splash ||
      path == AppRoutes.onboarding ||
      AppRoutes.publicAuthRoutes.contains(path)) {
    return null;
  }
  return from;
}

String? _originalLocation(Uri uri) {
  if (uri.path == AppRoutes.home && uri.query.isEmpty) return null;
  return sanitizeFrom(uri.toString());
}

String _withFrom(String path, String? from) {
  if (from == null) return path;
  return Uri(path: path, queryParameters: {'from': from}).toString();
}
