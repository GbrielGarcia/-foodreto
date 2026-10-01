import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import 'join_code_dialog.dart';

/// "+ Crear reto" y "Unirme con código". En pantallas anchas van en fila.
class ChallengeActions extends StatelessWidget {
  const ChallengeActions({super.key});

  Future<void> _join(BuildContext context) async {
    final code = await showJoinCodeDialog(context);
    if (code != null && context.mounted) {
      await context.push<void>(AppRoutes.joinPath(code));
    }
  }

  @override
  Widget build(BuildContext context) {
    final create = FilledButton.icon(
      onPressed: () => context.push(AppRoutes.create),
      icon: const Icon(Icons.add_rounded),
      label: const Text('CREAR RETO'),
    );
    final join = OutlinedButton.icon(
      onPressed: () => _join(context),
      icon: const Icon(Icons.qr_code_rounded),
      label: const Text('UNIRME CON CÓDIGO'),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 480) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              create,
              const SizedBox(height: AppSpacing.sm),
              join,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: create),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: join),
          ],
        );
      },
    );
  }
}
