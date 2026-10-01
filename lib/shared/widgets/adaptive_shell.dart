import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_spacing.dart';

class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

// El orden debe coincidir con las ramas de `app_router.dart`.
const _destinations = [
  _Destination('Inicio', Icons.home_outlined, Icons.home_rounded),
  _Destination('Explorar', Icons.map_outlined, Icons.map_rounded),
  _Destination(
    'Retos',
    Icons.local_fire_department_outlined,
    Icons.local_fire_department_rounded,
  ),
  _Destination(
    'Ranking',
    Icons.emoji_events_outlined,
    Icons.emoji_events_rounded,
  ),
  _Destination('Perfil', Icons.person_outline, Icons.person_rounded),
];

/// Barra inferior en móvil y `NavigationRail` en tablet/escritorio.
class AdaptiveShell extends StatelessWidget {
  const AdaptiveShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onSelect(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    if (width < Breakpoints.medium) {
      return Scaffold(
        body: navigationShell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: _onSelect,
          destinations: [
            for (final d in _destinations)
              NavigationDestination(
                icon: Icon(d.icon),
                selectedIcon: Icon(d.selectedIcon),
                label: d.label,
              ),
          ],
        ),
      );
    }

    final extended = width >= Breakpoints.expanded;
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: extended,
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: _onSelect,
            labelType: extended
                ? NavigationRailLabelType.none
                : NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Text(
                extended ? '🔥 FoodReto' : '🔥',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            destinations: [
              for (final d in _destinations)
                NavigationRailDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selectedIcon),
                  label: Text(d.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(child: navigationShell),
        ],
      ),
    );
  }
}
