import 'package:flutter_test/flutter_test.dart';
import 'package:foodreto/core/router/app_routes.dart';
import 'package:foodreto/core/router/auth_redirect.dart';

String? redirect(
  bool? signedIn,
  String location, {
  bool? isSuperAdmin = false,
}) =>
    authRedirect(
      isSignedIn: signedIn,
      uri: Uri.parse(location),
      isSuperAdmin: isSuperAdmin,
    );

void main() {
  group('sesión sin resolver', () {
    test('muestra splash sin destino para la raíz', () {
      expect(redirect(null, '/'), AppRoutes.splash);
    });

    test('conserva el destino original', () {
      expect(redirect(null, '/join/AB12CD'), '/splash?from=%2Fjoin%2FAB12CD');
    });

    test('no redirige si ya está en splash', () {
      expect(redirect(null, '/splash'), isNull);
    });
  });

  group('sin sesión', () {
    test('las rutas protegidas van a login', () {
      expect(redirect(false, '/profile'), '/login?from=%2Fprofile');
      expect(redirect(false, '/'), AppRoutes.login);
    });

    test('login y registro son accesibles', () {
      expect(redirect(false, '/login'), isNull);
      expect(redirect(false, '/register?from=%2Fjoin%2FAB12CD'), isNull);
    });

    test('desde splash pasa el destino a login', () {
      expect(
        redirect(false, '/splash?from=%2Fjoin%2FAB12CD'),
        '/login?from=%2Fjoin%2FAB12CD',
      );
    });
  });

  group('con sesión', () {
    test('sale de login hacia el destino original', () {
      expect(redirect(true, '/login?from=%2Fjoin%2FAB12CD'), '/join/AB12CD');
    });

    test('sale de login/splash hacia inicio si no hay destino', () {
      expect(redirect(true, '/login'), AppRoutes.home);
      expect(redirect(true, '/splash'), AppRoutes.home);
    });

    test('no toca las rutas protegidas', () {
      expect(redirect(true, '/rankings'), isNull);
    });
  });

  group('perfil (onboarding)', () {
    String? withProfile(ProfileStatus status, String location) => authRedirect(
      isSignedIn: true,
      uri: Uri.parse(location),
      profile: status,
      isSuperAdmin: false,
    );

    test('sin perfil va a onboarding conservando el destino', () {
      expect(withProfile(ProfileStatus.missing, '/'), AppRoutes.onboarding);
      expect(
        withProfile(ProfileStatus.missing, '/join/AB12CD'),
        '/onboarding?from=%2Fjoin%2FAB12CD',
      );
      expect(withProfile(ProfileStatus.missing, '/onboarding'), isNull);
    });

    test('perfil cargando espera en splash', () {
      expect(
        withProfile(ProfileStatus.unknown, '/profile'),
        startsWith('/splash'),
      );
    });

    test('con perfil sale de onboarding hacia el destino', () {
      expect(
        withProfile(ProfileStatus.complete, '/onboarding'),
        AppRoutes.home,
      );
      expect(
        withProfile(
          ProfileStatus.complete,
          '/onboarding?from=%2Fjoin%2FAB12CD',
        ),
        '/join/AB12CD',
      );
      expect(withProfile(ProfileStatus.complete, '/profile/edit'), isNull);
    });

    test('from no puede apuntar a onboarding', () {
      expect(sanitizeFrom('/onboarding'), isNull);
    });
  });

  group('super admin', () {
    String? adminRedirect(
      String location, {
      bool? isSuperAdmin = true,
    }) =>
        authRedirect(
          isSignedIn: true,
          uri: Uri.parse(location),
          profile: ProfileStatus.complete,
          isSuperAdmin: isSuperAdmin,
        );

    test('tras login/splash va al panel /admin', () {
      expect(adminRedirect('/login'), AppRoutes.admin);
      expect(adminRedirect('/splash'), AppRoutes.admin);
      expect(adminRedirect('/onboarding'), AppRoutes.admin);
    });

    test('respeta from hacia /admin/*', () {
      expect(
        adminRedirect('/login?from=%2Fadmin%2Festablishments'),
        AppRoutes.adminEstablishments,
      );
    });

    test('en la raíz del shell de usuario lo manda a /admin', () {
      expect(adminRedirect('/'), AppRoutes.admin);
    });

    test('puede quedarse en rutas /admin', () {
      expect(adminRedirect('/admin'), isNull);
      expect(adminRedirect('/admin/establishments'), isNull);
      expect(adminRedirect('/admin/account'), isNull);
    });

    test('puede abrir la app de usuario a propósito', () {
      expect(adminRedirect('/explore'), isNull);
    });

    test('no-admin no entra a /admin', () {
      expect(adminRedirect('/admin', isSuperAdmin: false), AppRoutes.home);
      expect(
        adminRedirect('/admin/establishments', isSuperAdmin: false),
        AppRoutes.home,
      );
    });

    test('espera en splash mientras resuelve isSuperAdmin', () {
      expect(
        adminRedirect('/login', isSuperAdmin: null),
        startsWith('/splash'),
      );
      expect(adminRedirect('/admin', isSuperAdmin: null), startsWith('/splash'));
    });
  });

  group('sanitizeFrom', () {
    test('rechaza URLs externas y protocolo relativo', () {
      expect(sanitizeFrom('https://evil.com'), isNull);
      expect(sanitizeFrom('//evil.com'), isNull);
    });

    test('rechaza rutas de auth para evitar bucles', () {
      expect(sanitizeFrom('/login'), isNull);
      expect(sanitizeFrom('/splash?from=/x'), isNull);
    });

    test('acepta rutas internas', () {
      expect(sanitizeFrom('/join/AB12CD'), '/join/AB12CD');
    });
  });
}
