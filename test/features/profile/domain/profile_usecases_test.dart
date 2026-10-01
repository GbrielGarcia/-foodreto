import 'package:flutter_test/flutter_test.dart';
import 'package:foodreto/core/avatar/avatar_config.dart';
import 'package:foodreto/core/error/result.dart';
import 'package:foodreto/features/profile/data/repositories/in_memory_profile_repository.dart';
import 'package:foodreto/features/profile/domain/entities/user_profile.dart';
import 'package:foodreto/features/profile/domain/entities/username_availability.dart';
import 'package:foodreto/features/profile/domain/failures/profile_failure.dart';
import 'package:foodreto/features/profile/domain/usecases/profile_usecases.dart';
import 'package:foodreto/features/profile/domain/value_objects/username.dart';

const _avatar = AvatarConfig(style: 'adventurer', seed: 'seed');

NewProfile _profile(String uid, String username) => NewProfile(
  uid: uid,
  username: username,
  displayName: 'Nombre $uid',
  avatar: _avatar,
);

void main() {
  late InMemoryProfileRepository repository;
  late CreateProfileWithUsername create;
  late UpdateProfile update;
  late CheckUsernameAvailability check;

  setUp(() {
    repository = InMemoryProfileRepository();
    create = CreateProfileWithUsername(repository);
    update = UpdateProfile(repository);
    check = CheckUsernameAvailability(repository);
  });
  tearDown(() => repository.dispose());

  group('checkUsernameAvailability', () {
    test('formato inválido no consulta el repositorio', () async {
      final result = await check('ga');
      expect(
        (result as Success<UsernameAvailability>).value,
        isA<UsernameInvalid>().having(
          (e) => e.error,
          'error',
          UsernameError.tooShort,
        ),
      );
    });

    test('libre, ocupado y propio', () async {
      await create(_profile('a', 'gabriel'));

      expect((await check('liss') as Success).value, isA<UsernameAvailable>());
      expect((await check('GABRIEL') as Success).value, isA<UsernameTaken>());
      expect(
        (await check('gabriel', currentUid: 'a') as Success).value,
        isA<UsernameOwned>(),
      );
    });
  });

  group('createUsername (onboarding)', () {
    test('guarda el username en minúsculas', () async {
      final result = await create(_profile('a', '  @Gabriel_Dev '));
      expect((result as Success<UserProfile>).value.username, 'gabriel_dev');
      expect(repository.usernameIndex, {'gabriel_dev': 'a'});
    });

    test('no permite el mismo username con otra capitalización', () async {
      await create(_profile('a', 'gabriel'));
      final result = await create(_profile('b', 'Gabriel'));
      expect(
        (result as Err).failure,
        isA<ProfileFailure>().having((f) => f.code, 'code', 'username-taken'),
      );
    });

    test('valida antes de llegar al repositorio', () async {
      final result = await create(_profile('a', 'gabriel guaman'));
      expect((result as Err).failure.code, 'invalid-data');
      expect(repository.usernameIndex, isEmpty);
    });

    test('no crea dos perfiles para el mismo usuario', () async {
      await create(_profile('a', 'gabriel'));
      final result = await create(_profile('a', 'otro_nombre'));
      expect((result as Err).failure.code, 'already-exists');
      expect(repository.usernameIndex, {'gabriel': 'a'});
    });
  });

  group('updateUsername', () {
    test('libera el anterior y reserva el nuevo', () async {
      await create(_profile('a', 'gabriel'));
      final result = await UpdateUsername(update)('a', 'Gabo');
      expect(result.isSuccess, isTrue);
      expect(repository.usernameIndex, {'gabo': 'a'});

      // El anterior queda libre para otra persona.
      final other = await create(_profile('b', 'gabriel'));
      expect(other.isSuccess, isTrue);
    });

    test('no puede quitarle el username a otro', () async {
      await create(_profile('a', 'gabriel'));
      await create(_profile('b', 'liss'));
      final result = await UpdateUsername(update)('b', 'gabriel');
      expect((result as Err).failure.code, 'username-taken');
      expect(repository.usernameIndex, {'gabriel': 'a', 'liss': 'b'});
    });
  });

  group('updateProfile', () {
    test('valida nombre y descripción', () async {
      await create(_profile('a', 'gabriel'));
      final emptyName = await update(
        'a',
        const ProfileChanges(displayName: '  '),
      );
      final longBio = await update('a', ProfileChanges(bio: 'x' * 161));
      expect((emptyName as Err).failure.code, 'invalid-data');
      expect((longBio as Err).failure.code, 'invalid-data');
    });

    test('sin cambios no escribe', () async {
      final result = await update('nadie', const ProfileChanges());
      expect(result.isSuccess, isTrue);
    });

    test('actualiza avatar y bio', () async {
      await create(_profile('a', 'gabriel'));
      const avatar = AvatarConfig(style: 'micah', seed: 'nuevo');
      await update('a', const ProfileChanges(bio: 'Hola', avatar: avatar));
      final profile = await repository.watchProfile('a').first;
      expect(profile?.bio, 'Hola');
      expect(profile?.avatar, avatar);
    });
  });
}
