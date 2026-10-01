import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/firebase/functions_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/services/establishment_admin_service.dart';
import '../../data/services/establishment_media_service.dart';
import '../../domain/entities/establishment_status.dart';
import '../../domain/entities/restaurant.dart';
import 'restaurant_providers.dart';

final establishmentAdminServiceProvider =
    Provider<EstablishmentAdminService>((ref) {
  final config = ref.watch(appConfigProvider);
  return EstablishmentAdminService(
    functions: config.usesCloudFunctions
        ? ref.watch(firebaseFunctionsProvider)
        : null,
    preferCallables: config.usesCloudFunctions,
  );
});

final establishmentMediaServiceProvider =
    Provider<EstablishmentMediaService>((ref) => EstablishmentMediaService());

final myEstablishmentsProvider =
    FutureProvider.autoDispose<List<Restaurant>>((ref) async {
  final uid = ref.watch(currentUserProvider)?.id;
  if (uid == null) return const [];
  final result = await ref.watch(restaurantRepositoryProvider).listMine(uid);
  return result.fold(onSuccess: (v) => v, onFailure: (f) => throw f);
});

final adminEstablishmentsProvider = FutureProvider.autoDispose
    .family<List<Restaurant>, EstablishmentStatus>((ref, status) async {
  final page = await ref
      .watch(restaurantRepositoryProvider)
      .listByStatus(status, limit: 50);
  return page.fold(onSuccess: (p) => p.items, onFailure: (f) => throw f);
});

final establishmentDetailProvider = FutureProvider.autoDispose
    .family<Restaurant?, String>((ref, id) async {
  final result = await ref.watch(restaurantRepositoryProvider).getById(id);
  return result.fold(onSuccess: (r) => r, onFailure: (f) => throw f);
});
