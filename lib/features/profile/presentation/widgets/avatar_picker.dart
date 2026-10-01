import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/avatar/avatar_config.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/user_avatar.dart';

/// Abre el selector de avatar. Devuelve la configuración confirmada o `null`.
Future<AvatarConfig?> showAvatarPicker(
  BuildContext context, {
  required AvatarConfig initial,
}) {
  final isCompact = MediaQuery.sizeOf(context).width < Breakpoints.medium;
  if (isCompact) {
    return showModalBottomSheet<AvatarConfig>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => AvatarPicker(initial: initial),
    );
  }
  return showDialog<AvatarConfig>(
    context: context,
    builder: (_) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 760),
        child: AvatarPicker(initial: initial),
      ),
    ),
  );
}

class AvatarPicker extends StatefulWidget {
  const AvatarPicker({super.key, required this.initial, this.random});

  final AvatarConfig initial;

  /// Inyectable para tests deterministas.
  final Random? random;

  @override
  State<AvatarPicker> createState() => _AvatarPickerState();
}

class _AvatarPickerState extends State<AvatarPicker> {
  static const _galleryLength = 8;

  late AvatarConfig _current = widget.initial;
  late final Random _random = widget.random ?? Random.secure();
  late List<String> _gallerySeeds = _newSeeds();
  late final _seedController = TextEditingController(text: _current.seed);

  List<String> _newSeeds() => List.generate(
    _galleryLength,
    (_) => AvatarConfig.randomSeed(random: _random),
  );

  @override
  void dispose() {
    _seedController.dispose();
    super.dispose();
  }

  void _update(AvatarConfig next) {
    setState(() => _current = next);
    if (_seedController.text != next.seed) _seedController.text = next.seed;
  }

  void _randomize() {
    HapticFeedback.selectionClick();
    _update(_current.copyWith(seed: AvatarConfig.randomSeed(random: _random)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final seedValid = AvatarConfig.isValidSeed(_seedController.text);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Elige tu avatar',
            style: theme.textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          Center(child: UserAvatar(avatar: _current, size: 132, ring: true)),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: TextButton.icon(
              onPressed: _randomize,
              icon: const Text('🎲', style: TextStyle(fontSize: 20)),
              label: const Text('Generar otro'),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _Label('Estilo'),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final style in AvatarConfig.styles)
                ChoiceChip(
                  label: Text(style.label),
                  selected: _current.style == style.id,
                  onSelected: (_) =>
                      _update(_current.copyWith(style: style.id)),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _Label('Fondo'),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final color in AvatarConfig.backgroundColors)
                _ColorSwatch(
                  hex: color,
                  selected: _current.backgroundColor == color,
                  onTap: () =>
                      _update(_current.copyWith(backgroundColor: color)),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              const Expanded(child: _Label('Galería')),
              IconButton(
                tooltip: 'Más opciones',
                onPressed: () => setState(() => _gallerySeeds = _newSeeds()),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 88,
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
            ),
            itemCount: _gallerySeeds.length,
            itemBuilder: (context, index) {
              final option = _current.copyWith(seed: _gallerySeeds[index]);
              return InkWell(
                customBorder: const CircleBorder(),
                onTap: () => _update(option),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  child: LayoutBuilder(
                    builder: (context, constraints) => UserAvatar(
                      avatar: option,
                      size: constraints.biggest.shortestSide,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _seedController,
            maxLength: AvatarConfig.maxSeedLength,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\w\-]')),
            ],
            decoration: InputDecoration(
              labelText: 'Semilla',
              helperText: 'La misma semilla genera siempre el mismo avatar.',
              errorText: seedValid ? null : 'Escribe al menos un carácter.',
              prefixIcon: const Icon(Icons.tag_rounded),
            ),
            onChanged: (value) {
              if (AvatarConfig.isValidSeed(value)) {
                setState(() => _current = _current.copyWith(seed: value));
              } else {
                setState(() {});
              }
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: seedValid
                ? () => Navigator.of(context).pop(_current)
                : null,
            child: const Text('USAR ESTE AVATAR'),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.hex,
    required this.selected,
    required this.onTap,
  });

  final String hex;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Color(0xFF000000 | int.parse(hex, radix: 16));
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Fondo $hex',
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 3 : 1,
            ),
          ),
          child: selected
              ? Icon(Icons.check_rounded, color: scheme.onSurface, size: 20)
              : null,
        ),
      ),
    );
  }
}
