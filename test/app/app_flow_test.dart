import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodreto/app/app.dart';
import 'package:foodreto/core/config/app_config.dart';
import 'package:foodreto/core/router/app_router.dart';
import 'package:foodreto/shared/widgets/user_avatar.dart';

ProviderContainer _localContainer() => ProviderContainer.test(
  overrides: [
    appConfigProvider.overrideWithValue(
      const AppConfig(backendMode: BackendMode.local),
    ),
    avatarNetworkEnabledProvider.overrideWithValue(false),
  ],
);

Future<void> _pumpApp(
  WidgetTester tester,
  ProviderContainer container, {
  Size size = const Size(390, 844),
}) async {
  tester.view
    ..physicalSize = size * 3
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const FoodRetoApp()),
  );
  await tester.pumpAndSettle();
}

/// Desplaza hasta el widget antes de pulsarlo (pantallas pequeñas).
Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Espera la comprobación de disponibilidad del username (debounce).
Future<void> _settleAvailability(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

Future<void> _signUp(
  WidgetTester tester, {
  String name = 'Gabriel',
  String email = 'gabriel@foodreto.app',
}) async {
  await _tap(tester, find.text('¿No tienes cuenta? Crear cuenta'));

  await tester.enterText(find.widgetWithText(TextFormField, 'Nombre'), name);
  await tester.enterText(find.widgetWithText(TextFormField, 'Correo'), email);
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Contraseña'),
    'secreto123',
  );
  await _tap(tester, find.text('CREAR CUENTA'));
}

/// Completa el onboarding con el username sugerido o [username].
Future<void> _completeOnboarding(
  WidgetTester tester, {
  String? username,
}) async {
  expect(find.text('Crea tu perfil'), findsOneWidget);
  if (username != null) {
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Username'),
      username,
    );
  }
  await _settleAvailability(tester);
  await _tap(tester, find.text('EMPEZAR'));
}

Future<void> _register(WidgetTester tester) async {
  await _signUp(tester);
  await _completeOnboarding(tester);
}

Future<void> _signOutFromProfile(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Más opciones'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Cerrar sesión'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('registro → inicio → perfil → cerrar sesión', (tester) async {
    await _pumpApp(tester, _localContainer());

    expect(find.text('ENTRAR'), findsOneWidget);
    expect(find.byType(Banner), findsOneWidget, reason: 'aviso de modo local');

    await _register(tester);
    expect(find.text('¿Qué vas a comer hoy?'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);

    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();
    expect(find.text('Gabriel'), findsOneWidget);

    await _signOutFromProfile(tester);
    expect(find.text('ENTRAR'), findsOneWidget);
  });

  testWidgets('un enlace de invitación sobrevive al registro', (tester) async {
    final container = _localContainer();
    await _pumpApp(tester, container);

    container.read(routerProvider).go('/join/ab23cd');
    await tester.pumpAndSettle();
    expect(find.text('ENTRAR'), findsOneWidget);

    await _register(tester);
    expect(
      container.read(routerProvider).state.uri.path.toUpperCase(),
      '/JOIN/AB23CD',
    );
    expect(find.text('Este reto no existe.'), findsOneWidget);
  });

  testWidgets('código inválido muestra error de validación', (tester) async {
    await _pumpApp(tester, _localContainer());
    await _register(tester);

    await tester.tap(find.text('UNIRME CON CÓDIGO'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'AB1');
    await tester.tap(find.text('Unirme'));
    await tester.pumpAndSettle();

    expect(find.text('Código de 6 caracteres.'), findsOneWidget);
  });

  testWidgets('en escritorio usa NavigationRail', (tester) async {
    await _pumpApp(tester, _localContainer(), size: const Size(1280, 800));
    await _register(tester);

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  group('perfil', () {
    testWidgets('autenticación → onboarding → perfil con @username', (
      tester,
    ) async {
      await _pumpApp(tester, _localContainer());
      await _signUp(tester, name: 'Liss Pérez');
      await _completeOnboarding(tester);

      await tester.tap(find.text('Perfil'));
      await tester.pumpAndSettle();
      expect(find.text('@liss_perez'), findsOneWidget);
      expect(find.text('Liss Pérez'), findsOneWidget);
      expect(find.text('Todavía no tienes retos'), findsOneWidget);
    });

    testWidgets('editar perfil cambia nombre y username', (tester) async {
      await _pumpApp(tester, _localContainer());
      await _register(tester);

      await tester.tap(find.text('Perfil'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('EDITAR PERFIL'));
      await tester.pumpAndSettle();
      expect(find.text('Editar perfil'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre'),
        'Gabriel Guamán',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Username'),
        'Gabriel_Dev',
      );
      await _settleAvailability(tester);
      expect(find.text('¡Disponible!'), findsOneWidget);

      await _tap(tester, find.text('GUARDAR'));
      expect(find.text('Guardado correctamente'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('@gabriel_dev'), findsOneWidget);
      expect(find.text('Gabriel Guamán'), findsOneWidget);
    });

    testWidgets('un username ocupado no se puede elegir', (tester) async {
      await _pumpApp(tester, _localContainer());
      await _register(tester);
      await tester.tap(find.text('Perfil'));
      await tester.pumpAndSettle();
      await _signOutFromProfile(tester);

      await _signUp(tester, name: 'Otro Gabriel', email: 'otro@foodreto.app');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Username'),
        'gabriel',
      );
      await _settleAvailability(tester);

      expect(find.text('Ya está en uso. Prueba con otro.'), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'EMPEZAR'),
      );
      expect(button.onPressed, isNull);
    });
  });

  group('categorías', () {
    testWidgets('inicio → ver todas → categoría', (tester) async {
      await _pumpApp(tester, _localContainer());
      await _register(tester);

      await _tap(tester, find.text('Ver todas'));
      expect(find.text('Categorías'), findsOneWidget);
      expect(find.text('Sushi'), findsOneWidget);

      await _tap(tester, find.text('Sushi'));
      expect(find.text('SUSHI'), findsOneWidget);
      expect(find.text('Se cuenta en piezas'), findsOneWidget);
      expect(find.text('Sin récord todavía'), findsOneWidget);
    });

    testWidgets('una categoría inexistente muestra estado vacío', (
      tester,
    ) async {
      final container = _localContainer();
      await _pumpApp(tester, container);
      await _register(tester);

      container.read(routerProvider).go('/category/no-existe');
      await tester.pumpAndSettle();
      expect(find.text('Categoría no encontrada'), findsOneWidget);
    });

    testWidgets('buscar filtra y avisa si no hay resultados', (tester) async {
      final container = _localContainer();
      await _pumpApp(tester, container, size: const Size(320, 640));
      await _register(tester);

      container.read(routerProvider).go('/categories');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'pízza');
      await tester.pumpAndSettle();
      expect(find.text('Pizza'), findsOneWidget);
      expect(find.text('Sushi'), findsNothing);

      await tester.enterText(find.byType(TextField), 'ceviche');
      await tester.pumpAndSettle();
      expect(find.text('No encontramos "ceviche"'), findsOneWidget);
    });
  });
}
