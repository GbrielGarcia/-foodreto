import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../../../core/avatar/avatar_config.dart';
import '../../../../shared/widgets/centered_content.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../category/domain/entities/food_category.dart';
import '../../../category/presentation/providers/category_providers.dart';
import '../../../profile/domain/entities/user_profile.dart';
import '../../../restaurant/domain/entities/restaurant.dart';
import '../../../restaurant/presentation/providers/restaurant_providers.dart';
import '../../../social/domain/entities/friendship.dart';
import '../../../social/presentation/providers/social_providers.dart';
import '../../domain/entities/challenge.dart';
import '../providers/challenge_controllers.dart';

enum _PlayMode { normal, samePhoneFriend, samePhoneGuest }

const _drinkSlugs = {
  'cerveza',
  'micheladas',
  'cocteles',
  'tequila',
  'mezcal',
  'vino',
  'shots',
  'cafe',
  'ron',
  'whisky',
  'vodka',
  'margaritas',
  'mojitos',
  'sangria',
  'limonada',
  'jugos',
  'smoothies',
  'refrescos',
};

class CreateChallengePage extends ConsumerStatefulWidget {
  const CreateChallengePage({super.key, this.initialCategoryId});

  final String? initialCategoryId;

  @override
  ConsumerState<CreateChallengePage> createState() =>
      _CreateChallengePageState();
}

class _CreateChallengePageState extends ConsumerState<CreateChallengePage> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _guestName = TextEditingController();
  final _guestEmail = TextEditingController();
  final _guestPassword = TextEditingController();

  String? _categoryId;
  Restaurant? _restaurant;
  var _visibility = ChallengeVisibility.private;
  var _maxParticipants = Challenge.defaultMaxParticipants;
  var _playMode = _PlayMode.normal;
  final _friendIds = <String>{};
  final _friendProfiles = <String, UserProfile>{};

  @override
  void initState() {
    super.initState();
    _categoryId = widget.initialCategoryId;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _guestName.dispose();
    _guestEmail.dispose();
    _guestPassword.dispose();
    super.dispose();
  }

  Future<void> _pickCategory(List<FoodCategory> categories) async {
    final picked = await showModalBottomSheet<FoodCategory>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CategorySheet(
        categories: categories,
        selectedId: _categoryId,
      ),
    );
    if (picked != null) setState(() => _categoryId = picked.id);
  }

  Future<void> _submit() async {
    final categoryId = _categoryId;
    if (categoryId == null) return;

    if (_playMode == _PlayMode.samePhoneFriend && _friendIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Elige al menos un amigo para jugar en este celular.'),
        ),
      );
      return;
    }
    if (_playMode == _PlayMode.samePhoneGuest) {
      if (_guestName.text.trim().isEmpty ||
          _guestEmail.text.trim().isEmpty ||
          _guestPassword.text.length < 6) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Completa nombre, correo y contrasena (min. 6) del invitado.',
            ),
          ),
        );
        return;
      }
    }

    final sameDevice = _playMode != _PlayMode.normal;
    final partnerCount = _playMode == _PlayMode.samePhoneFriend
        ? _friendIds.length
        : (_playMode == _PlayMode.samePhoneGuest ? 1 : 0);
    final challenge = await ref
        .read(createChallengeControllerProvider.notifier)
        .create(
          NewChallenge(
            categoryId: categoryId,
            restaurantId: _restaurant?.id,
            title: _title.text,
            description: _description.text,
            visibility: sameDevice ? ChallengeVisibility.friends : _visibility,
            maxParticipants: sameDevice ? partnerCount + 1 : _maxParticipants,
            sameDevicePlay: sameDevice,
            sameDevicePartnerIds: _playMode == _PlayMode.samePhoneFriend
                ? _friendIds.toList()
                : const [],
            sameDeviceGuestName: _playMode == _PlayMode.samePhoneGuest
                ? _guestName.text.trim()
                : null,
            sameDeviceGuestEmail: _playMode == _PlayMode.samePhoneGuest
                ? _guestEmail.text.trim()
                : null,
            sameDeviceGuestPassword: _playMode == _PlayMode.samePhoneGuest
                ? _guestPassword.text
                : null,
          ),
        );
    if (challenge != null && mounted) {
      context.pushReplacement(AppRoutes.challengePath(challenge.id));
    }
  }

  Future<void> _pickRestaurant() async {
    final picked = await showModalBottomSheet<_RestaurantChoice>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => const _RestaurantPicker(),
    );
    if (picked != null) setState(() => _restaurant = picked.restaurant);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final save = ref.watch(createChallengeControllerProvider);
    final categories = ref.watch(categoriesProvider);
    final selected = categories.value
        ?.where((c) => c.id == _categoryId)
        .firstOrNull;
    final uid = ref.watch(currentUserProvider)?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear reto'),
        leading: BackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(AppRoutes.home),
        ),
      ),
      body: switch (categories) {
        AsyncData(:final value) when value.isEmpty => const EmptyStateView(
          emoji: '\u{1F37D}',
          title: 'Aun no hay categorias',
          message: 'Para crear un reto hace falta el menu de comidas.',
        ),
        AsyncError() => ErrorStateView(
          message: 'No pudimos cargar las categorias.',
          onRetry: () => ref.invalidate(categoriesProvider),
        ),
        AsyncData(:final value) => CenteredContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Comida o bebida',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Material(
                color: AppColors.creamSoft,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _pickCategory(value),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Text(
                          selected?.icon ?? '\u{1F37D}',
                          style: const TextStyle(fontSize: 28),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selected?.name ?? 'Elegir categoria',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                selected == null
                                    ? 'Toca para buscar comida o bebida'
                                    : 'Se cuenta en ${selected.defaultUnit.plural}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.expand_more_rounded),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _Label('Donde (opcional)'),
              OutlinedButton.icon(
                onPressed: _pickRestaurant,
                style: OutlinedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.md,
                  ),
                ),
                icon: const Icon(Icons.storefront_rounded),
                label: Text(
                  _restaurant == null
                      ? 'Sin restaurante'
                      : '${_restaurant!.name} · ${_restaurant!.city}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _title,
                maxLength: Challenge.maxTitleLength,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Titulo (opcional)',
                  hintText: selected == null
                      ? 'Reto de...'
                      : 'Reto de ${selected.name}',
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _description,
                maxLength: Challenge.maxDescriptionLength,
                minLines: 1,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Descripcion (opcional)',
                  hintText: 'Reglas, apuestas...',
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _Label('Modo de juego'),
              SegmentedButton<_PlayMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: _PlayMode.normal,
                    label: Text('Normal'),
                  ),
                  ButtonSegment(
                    value: _PlayMode.samePhoneFriend,
                    label: Text('Amigo'),
                  ),
                  ButtonSegment(
                    value: _PlayMode.samePhoneGuest,
                    label: Text('Libre'),
                  ),
                ],
                selected: {_playMode},
                onSelectionChanged: (s) => setState(() {
                  _playMode = s.first;
                  if (_playMode != _PlayMode.normal) {
                    _maxParticipants = 2;
                    _visibility = ChallengeVisibility.friends;
                  }
                }),
              ),
              const SizedBox(height: 6),
              Text(
                switch (_playMode) {
                  _PlayMode.normal =>
                    'Cada uno con su celular. Codigo o invitacion.',
                  _PlayMode.samePhoneFriend =>
                    'Elige 1 o mas amigos. Juegan en este celular; despues confirman el resultado.',
                  _PlayMode.samePhoneGuest =>
                    'Creas cuenta rapida del invitado y juegan aqui. Sin internet se sincroniza al volver.',
                },
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (_playMode == _PlayMode.samePhoneFriend && uid != null) ...[
                const SizedBox(height: 12),
                _FriendPicker(
                  uid: uid,
                  selectedIds: _friendIds,
                  onToggle: (id, profile) => setState(() {
                    if (_friendIds.contains(id)) {
                      _friendIds.remove(id);
                      _friendProfiles.remove(id);
                    } else if (_friendIds.length <
                        Challenge.maxParticipantsLimit - 1) {
                      _friendIds.add(id);
                      _friendProfiles[id] = profile;
                    }
                  }),
                ),
                if (_friendIds.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Competidores: ${_friendIds.length} '
                      '(${_friendProfiles.values.map((p) => p.displayName).join(', ')})',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.flameDeep,
                      ),
                    ),
                  ),
              ],
              if (_playMode == _PlayMode.samePhoneGuest) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _guestName,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del invitado',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _guestEmail,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Correo del invitado',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _guestPassword,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Contrasena (min. 6)',
                  ),
                ),
              ],
              if (_playMode == _PlayMode.normal) ...[
                const SizedBox(height: AppSpacing.lg),
                _Label('Quien puede entrar'),
                SegmentedButton<ChallengeVisibility>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: ChallengeVisibility.private,
                      label: Text('Privado'),
                    ),
                    ButtonSegment(
                      value: ChallengeVisibility.public,
                      label: Text('Publico'),
                    ),
                    ButtonSegment(
                      value: ChallengeVisibility.friends,
                      label: Text('Amigos'),
                    ),
                  ],
                  selected: {_visibility},
                  onSelectionChanged: (s) =>
                      setState(() => _visibility = s.first),
                ),
                const SizedBox(height: AppSpacing.lg),
                _ParticipantsStepper(
                  value: _maxParticipants,
                  onChanged: (v) => setState(() => _maxParticipants = v),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              if (save.status == SaveStatus.error && save.failure != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Text(
                    save.failure!.message,
                    style: TextStyle(color: theme.colorScheme.error),
                    textAlign: TextAlign.center,
                  ),
                ),
              FilledButton(
                onPressed: _categoryId == null || save.isSaving
                    ? null
                    : _submit,
                child: Text(save.isSaving ? 'CREANDO...' : 'CREAR RETO'),
              ),
            ],
          ),
        ),
        _ => const LoadingStateView(),
      },
    );
  }
}

class _CategorySheet extends StatefulWidget {
  const _CategorySheet({
    required this.categories,
    required this.selectedId,
  });

  final List<FoodCategory> categories;
  final String? selectedId;

  @override
  State<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends State<_CategorySheet> {
  var _query = '';
  var _filter = 0; // 0 all, 1 food, 2 drinks

  @override
  Widget build(BuildContext context) {
    final q = TextNormalizer.normalize(_query);
    var list = widget.categories;
    if (_filter == 1) {
      list = list.where((c) => !_drinkSlugs.contains(c.slug)).toList();
    } else if (_filter == 2) {
      list = list.where((c) => _drinkSlugs.contains(c.slug)).toList();
    }
    if (q.isNotEmpty) {
      list = list
          .where((c) => TextNormalizer.normalize(c.name).contains(q))
          .toList();
    }

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Que vas a comer',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 8),
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'Buscar alitas, cerveza...',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: [
                ChoiceChip(
                  label: const Text('Todas'),
                  selected: _filter == 0,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => setState(() => _filter = 0),
                ),
                ChoiceChip(
                  label: const Text('Comida'),
                  selected: _filter == 1,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => setState(() => _filter = 1),
                ),
                ChoiceChip(
                  label: const Text('Bebidas'),
                  selected: _filter == 2,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => setState(() => _filter = 2),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.85,
                ),
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final c = list[i];
                  final selected = c.id == widget.selectedId;
                  return Material(
                    color: selected ? AppColors.blush : AppColors.creamSoft,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Navigator.pop(context, c),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(c.icon, style: const TextStyle(fontSize: 22)),
                            const SizedBox(height: 4),
                            Text(
                              c.name,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 10,
                                color: selected
                                    ? AppColors.flameDeep
                                    : AppColors.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FriendPicker extends ConsumerWidget {
  const _FriendPicker({
    required this.uid,
    required this.selectedIds,
    required this.onToggle,
  });

  final String uid;
  final Set<String> selectedIds;
  final void Function(String id, UserProfile profile) onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendsAsync = ref.watch(friendsListProvider);
    return friendsAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (_, _) => const Text('No se pudieron cargar amigos.'),
      data: (friends) {
        final accepted = [
          for (final f in friends)
            if (f.status == FriendshipStatus.accepted) f,
        ];
        if (accepted.isEmpty) {
          return const Text(
            'No tienes amigos aceptados. Agrega amigos para jugar en el mismo celular.',
          );
        }
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final f in accepted) ...[
              Builder(
                builder: (context) {
                  final snap = f.otherSnapshot(uid);
                  final selected = selectedIds.contains(snap.userId);
                  return FilterChip(
                    selected: selected,
                    label: Text(snap.displayName),
                    onSelected: (_) {
                      onToggle(
                        snap.userId,
                        UserProfile(
                          uid: snap.userId,
                          username: snap.username,
                          displayName: snap.displayName,
                          avatar: AvatarConfig(
                            style: snap.avatarStyle ?? 'lorelei',
                            seed: snap.avatarSeed ?? snap.userId,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ],
        );
      },
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
    ),
  );
}

class _ParticipantsStepper extends StatelessWidget {
  const _ParticipantsStepper({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Maximo de participantes',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'Contandote a ti',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          onPressed: value > Challenge.minParticipants
              ? () => onChanged(value - 1)
              : null,
          icon: const Icon(Icons.remove_rounded),
        ),
        SizedBox(
          width: 40,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        IconButton.filledTonal(
          onPressed: value < Challenge.maxParticipantsLimit
              ? () => onChanged(value + 1)
              : null,
          icon: const Icon(Icons.add_rounded),
        ),
      ],
    );
  }
}

class _RestaurantChoice {
  const _RestaurantChoice(this.restaurant);
  final Restaurant? restaurant;
}

class _RestaurantPicker extends ConsumerStatefulWidget {
  const _RestaurantPicker();

  @override
  ConsumerState<_RestaurantPicker> createState() => _RestaurantPickerState();
}

class _RestaurantPickerState extends ConsumerState<_RestaurantPicker> {
  var _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = _query.trim();
    final results = query.length < 2
        ? null
        : ref.watch(restaurantSearchProvider(query));

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Restaurante', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Buscar por nombre...',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            ListTile(
              leading: const Icon(Icons.not_listed_location_outlined),
              title: const Text('Continuar sin restaurante'),
              onTap: () =>
                  Navigator.pop(context, const _RestaurantChoice(null)),
            ),
            const Divider(),
            Flexible(
              child: switch (results) {
                null => const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Escribe al menos 2 letras para buscar.',
                    textAlign: TextAlign.center,
                  ),
                ),
                AsyncData(:final value) => ListView(
                  shrinkWrap: true,
                  children: [
                    for (final r in value.where(
                      (r) => r.isActive && r.status.isPubliclyDiscoverable,
                    ))
                      ListTile(
                        leading: const Icon(Icons.storefront_rounded),
                        title: Text(r.name),
                        subtitle: Text(r.city),
                        onTap: () =>
                            Navigator.pop(context, _RestaurantChoice(r)),
                      ),
                  ],
                ),
                AsyncError() => const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No pudimos buscar ahora.'),
                ),
                _ => const Center(child: CircularProgressIndicator()),
              },
            ),
          ],
        ),
      ),
    );
  }
}
