import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodreto/core/avatar/avatar_config.dart';
import 'package:foodreto/core/error/result.dart';
import 'package:foodreto/features/profile/data/repositories/firestore_profile_repository.dart';
import 'package:foodreto/features/profile/domain/entities/user_profile.dart';
import 'package:foodreto/features/profile/domain/entities/user_statistics.dart';
import 'package:foodreto/features/profile/domain/entities/username_availability.dart';

const _avatar = AvatarConfig(
  style: 'avataaars',
  seed: 'gabriel123',
  options: {'backgroundColor': 'ffc53d'},
);

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreProfileRepository repository;

  setUp(() {
    db = FakeFirebaseFirestore();
    repository = FirestoreProfileRepository(db);
  });

  Future<Result<UserProfile>> createGabriel() => repository.createProfile(
    const NewProfile(
      uid: 'u1',
      username: 'gabriel',
      displayName: 'Gabriel Guaman',
      avatar: _avatar,
      email: 'gabriel@foodreto.app',
    ),
  );

  test('createProfile escribe users, usernames y el correo privado', () async {
    final result = await createGabriel();
    expect(result.isSuccess, isTrue);

    final user = (await db.doc('users/u1').get()).data()!;
    expect(user['uid'], 'u1');
    expect(user['username'], 'gabriel');
    expect(user['displayName'], 'Gabriel Guaman');
    expect(user['avatarStyle'], 'avataaars');
    expect(user['avatarSeed'], 'gabriel123');
    expect(user['avatarOptions'], {'backgroundColor': 'ffc53d'});
    expect(user['isActive'], isTrue);
    expect(user['visibility'], 'public');
    expect(user.containsKey('email'), isFalse, reason: 'el correo es privado');
    expect(user['createdAt'], isNotNull);

    final reservation = (await db.doc('usernames/gabriel').get()).data()!;
    expect(reservation['uid'], 'u1');

    final account = (await db.doc('users/u1/private/account').get()).data()!;
    expect(account['email'], 'gabriel@foodreto.app');
  });

  test('no permite reservar un username ya reservado', () async {
    await createGabriel();
    final result = await repository.createProfile(
      const NewProfile(
        uid: 'u2',
        username: 'gabriel',
        displayName: 'Otro',
        avatar: _avatar,
      ),
    );
    expect((result as Err).failure.code, 'username-taken');
    expect((await db.doc('users/u2').get()).exists, isFalse);
  });

  test('checkUsernameAvailability', () async {
    await createGabriel();
    Future<UsernameAvailability> check(String name, [String? uid]) async =>
        (await repository.checkUsernameAvailability(name, currentUid: uid)
                as Success<UsernameAvailability>)
            .value;

    expect(await check('liss'), isA<UsernameAvailable>());
    expect(await check('gabriel'), isA<UsernameTaken>());
    expect(await check('gabriel', 'u1'), isA<UsernameOwned>());
  });

  test('cambiar username mueve la reserva en la misma transacción', () async {
    await createGabriel();
    final result = await repository.updateProfile(
      'u1',
      const ProfileChanges(username: 'gabo', displayName: 'Gabo'),
    );
    expect(result.isSuccess, isTrue);
    expect((await db.doc('usernames/gabriel').get()).exists, isFalse);
    expect((await db.doc('usernames/gabo').get()).data()?['uid'], 'u1');
    final user = (await db.doc('users/u1').get()).data()!;
    expect(user['username'], 'gabo');
    expect(user['displayName'], 'Gabo');
  });

  test('no cambia campos protegidos al actualizar', () async {
    await createGabriel();
    await repository.updateProfile('u1', const ProfileChanges(bio: 'Hola'));
    final user = (await db.doc('users/u1').get()).data()!;
    expect(user['bio'], 'Hola');
    expect(user['uid'], 'u1');
    expect(user['isActive'], isTrue);
  });

  test('updateProfile sin perfil devuelve not-found', () async {
    final result = await repository.updateProfile(
      'nadie',
      const ProfileChanges(bio: 'x'),
    );
    expect((result as Err).failure.code, 'not-found');
  });

  test('watchProfile emite null sin perfil y luego el perfil', () async {
    final emissions = repository.watchProfile('u1').take(2).toList();
    await createGabriel();
    final values = await emissions;
    expect(values.first, isNull);
    expect(values.last?.username, 'gabriel');
    expect(values.last?.avatar, _avatar);
  });

  test('estadísticas sin documento son cero', () async {
    final stats = await FirestoreUserStatisticsRepository(
      db,
    ).watchStatistics('u1').first;
    expect(stats.challengeCount, 0);
    expect(stats, isA<UserStatistics>());

    await db.doc('userStatistics/u1').set({
      'challengeCount': 12,
      'recordCount': 3,
      'totalUnits': 324,
      'restaurantCount': 8,
    });
    final updated = await FirestoreUserStatisticsRepository(
      db,
    ).watchStatistics('u1').first;
    expect(updated.challengeCount, 12);
    expect(updated.restaurantCount, 8);
  });
}
