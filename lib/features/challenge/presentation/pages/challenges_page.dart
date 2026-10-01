import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/centered_content.dart';
import '../../../../shared/widgets/state_views.dart';
import '../widgets/challenge_actions.dart';
import '../widgets/challenge_widgets.dart';

/// Pestaña "Retos": acciones principales y mis retos (historial básico).
class ChallengesPage extends StatelessWidget {
  const ChallengesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Retos')),
      body: const CenteredContent(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ChallengeActions(),
            SizedBox(height: AppSpacing.xl),
            SectionHeader(title: 'Mis retos'),
            MyChallengesList(),
          ],
        ),
      ),
    );
  }
}
