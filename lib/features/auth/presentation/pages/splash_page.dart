import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';

/// Se muestra mientras se resuelve la sesión al arrancar.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🔥', style: TextStyle(fontSize: 72)),
            SizedBox(height: AppSpacing.lg),
            SizedBox.square(
              dimension: 28,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
          ],
        ),
      ),
    );
  }
}
