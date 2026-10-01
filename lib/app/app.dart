import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../core/router/app_router.dart';
import '../core/theme/app_theme.dart';
import '../features/notifications/presentation/providers/system_notification_bridge.dart';

class FoodRetoApp extends ConsumerWidget {
  const FoodRetoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final config = ref.watch(appConfigProvider);
    // Puente global: push local al llegar docs a `notifications`.
    ref.watch(systemNotificationBridgeProvider);
    final banner = config.isLocal
        ? 'LOCAL'
        : (config.useEmulators ? 'EMULADOR' : null);

    return MaterialApp.router(
      title: 'FoodReto',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.light,
      routerConfig: router,
      builder: (context, child) {
        final content = child ?? const SizedBox.shrink();
        if (banner == null) return content;
        return Banner(
          message: banner,
          location: BannerLocation.topEnd,
          child: content,
        );
      },
    );
  }
}
