import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodreto/core/error/result.dart';
import 'package:foodreto/features/challenge/data/datasources/challenge_remote_data_source.dart';
import 'package:foodreto/features/challenge/data/models/challenge_dto.dart';
import 'package:foodreto/features/challenge/data/repositories/firestore_challenge_repository.dart';
import 'package:foodreto/features/challenge/domain/entities/challenge.dart';
import 'package:foodreto/features/challenge/domain/entities/challenge_event.dart';

import '../challenge_fixtures.dart';

T _value<T>(Result<T> r) =>
    r.fold(onSuccess: (v) => v, onFailure: (f) => throw f);

String? _code<T>(Result<T> r) =>
    r.fold(onSuccess: (_) => null, onFailure: (f) => f.code);

void main() {
  late FakeFirebaseFirestore db;
  late ChallengeRemoteDataSource source;
  late FirestoreChallengeRepository repository;
  late FirestoreChallengeEventRepository events;

  setUp(() {
    db = FakeFirebaseFirestore();
    source = ChallengeRemoteDataSource(db);
    repository = FirestoreChallengeRepository(source);
    events = FirestoreChallengeEventRepository(source);
  });

  test('crear escribe reto, reserva de código y host', () async {
    final c = _value(await repository.createChallenge(alitas, ana));

    final doc = (await db.doc('challenges/${c.id}').get()).data()!;
    expect(doc['status'], 'waiting');
    expect(doc['hostUserId'], 'a');
    expect(doc['participantIds'], ['a']);
    expect(doc['inviteCode'], c.inviteCode);
    expect(doc['startedAt'], isNull);

    final code = (await db.doc('inviteCodes/${c.inviteCode}').get()).data()!;
    expect(code['challengeId'], c.id);

    final host = (await db.doc('challenges/${c.id}/participants/a').get())
        .data()!;
    expect(host['role'], 'host');
    expect(host['currentCount'], 0);
    expect(host['displayName'], 'Ana');
  });

  test('un código ocupado se sustituye por otro', () async {
    final codes = ['QWERTY', 'QWERTY', 'ZXCVBN'];
    final repo = FirestoreChallengeRepository(
      source,
      newInviteCode: () => codes.removeAt(0),
    );
    final first = _value(await repo.createChallenge(alitas, ana));
    final second = _value(await repo.createChallenge(alitas, beto));
    expect(first.inviteCode, 'QWERTY');
    expect(second.inviteCode, 'ZXCVBN');
  });

  test('buscar por código', () async {
    final c = _value(await repository.createChallenge(alitas, ana));
    expect(_value(await repository.findByInviteCode(c.inviteCode))?.id, c.id);
    expect(_value(await repository.findByInviteCode('ZZZZZZ')), isNull);
  });

  test('unirse, lleno y ya dentro', () async {
    final c = _value(
      await repository.createChallenge(
        const NewChallenge(categoryId: 'alitas', maxParticipants: 2),
        ana,
      ),
    );
    expect((await repository.join(c.id, beto)).isSuccess, isTrue);
    expect(_code(await repository.join(c.id, beto)), 'already-joined');
    expect(_code(await repository.join(c.id, caro)), 'full');

    final doc = (await db.doc('challenges/${c.id}').get()).data()!;
    expect(doc['participantIds'], ['a', 'b']);
  });

  test('iniciar, contar y finalizar con resultado exacto', () async {
    final c = _value(await repository.createChallenge(alitas, ana));
    await repository.join(c.id, beto);
    expect(_code(await repository.start(c.id, 'b')), 'not-host');
    expect((await repository.start(c.id, 'a')).isSuccess, isTrue);

    for (final e in [
      eventFor('b'),
      eventFor('b'),
      eventFor('a'),
      eventFor('b', type: ChallengeEventType.decrement),
    ]) {
      expect((await events.recordEvent(c.id, e)).isSuccess, isTrue);
    }

    final b = (await db.doc('challenges/${c.id}/participants/b').get()).data()!;
    expect(b['currentCount'], 1);
    expect(b['lastEventId'], isA<String>());

    final storedEvents = _value(await events.getEvents(c.id));
    expect(storedEvents.length, 4);
    final event =
        (await db
                .doc(
                  'challenges/${c.id}/events/${storedEvents.first.clientEventId}',
                )
                .get())
            .data()!;
    expect(event['amount'], 1);
    expect(event['clientEventId'], storedEvents.first.clientEventId);

    final result = _value(await repository.finish(c.id, 'a'));
    expect(
      {for (final e in result.entries) e.userId: e.count},
      {'a': 1, 'b': 1},
    );
    expect(tallyEvents(storedEvents), {'a': 1, 'b': 1});

    // fake_cloud_firestore puede emitir el primer snapshot antes del commit:
    // se lee con get() (los listeners reales se prueban en el emulador).
    final saved = ResultDto.fromMap(
      c.id,
      (await db.doc('challengeResults/${c.id}').get()).data(),
    );
    expect(saved?.participantIds, ['a', 'b']);
    expect([for (final r in saved!.standings) r.position], [1, 1]);
    final doc = (await db.doc('challenges/${c.id}').get()).data()!;
    expect(doc['status'], 'finished');
  });

  test('mis retos y participantes en vivo', () async {
    final c = _value(await repository.createChallenge(alitas, ana));
    await repository.join(c.id, beto);

    final mine = await repository.watchUserChallenges('b').first;
    expect([for (final c in mine) c.id], [c.id]);

    final people = await FirestoreChallengeParticipantRepository(
      source,
    ).watchParticipants(c.id).first;
    expect([for (final p in people) p.userId], ['a', 'b']);
    expect(people.first.isHost, isTrue);
  });

  test('salir y cancelar', () async {
    final c = _value(await repository.createChallenge(alitas, ana));
    await repository.join(c.id, beto);
    expect(_code(await repository.leave(c.id, 'a')), 'host-cannot-leave');
    expect((await repository.leave(c.id, 'b')).isSuccess, isTrue);
    expect(
      (await db.doc('challenges/${c.id}/participants/b').get()).exists,
      isFalse,
    );
    final cancelled = await repository.cancel(c.id, 'a');
    expect(_code(cancelled), isNull);
    final doc = (await db.doc('challenges/${c.id}').get()).data()!;
    expect(doc['status'], ChallengeStatus.cancelled.name);
  });
}
