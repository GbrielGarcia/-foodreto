import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:foodreto/features/challenge/domain/entities/challenge.dart';
import 'package:foodreto/features/challenge/domain/entities/challenge_event.dart';
import 'package:foodreto/features/challenge/domain/entities/challenge_result.dart';
import 'package:foodreto/features/challenge/domain/value_objects/client_event_id.dart';
import 'package:foodreto/features/challenge/domain/value_objects/invite_code.dart';

import '../challenge_fixtures.dart';

void main() {
  group('ChallengeStatus', () {
    test('transiciones permitidas', () {
      expect(
        ChallengeStatus.draft.canTransitionTo(ChallengeStatus.waiting),
        isTrue,
      );
      expect(
        ChallengeStatus.waiting.canTransitionTo(ChallengeStatus.active),
        isTrue,
      );
      expect(
        ChallengeStatus.active.canTransitionTo(ChallengeStatus.finished),
        isTrue,
      );
      for (final s in [
        ChallengeStatus.draft,
        ChallengeStatus.waiting,
        ChallengeStatus.active,
      ]) {
        expect(s.canTransitionTo(ChallengeStatus.cancelled), isTrue);
      }
    });

    test('transiciones prohibidas', () {
      expect(
        ChallengeStatus.waiting.canTransitionTo(ChallengeStatus.finished),
        isFalse,
      );
      expect(
        ChallengeStatus.active.canTransitionTo(ChallengeStatus.waiting),
        isFalse,
      );
      for (final next in ChallengeStatus.values) {
        expect(ChallengeStatus.finished.canTransitionTo(next), isFalse);
        expect(ChallengeStatus.cancelled.canTransitionTo(next), isFalse);
      }
    });

    test('qué admite cada estado', () {
      expect(ChallengeStatus.waiting.acceptsParticipants, isTrue);
      expect(ChallengeStatus.active.acceptsParticipants, isFalse);
      expect(ChallengeStatus.active.acceptsEvents, isTrue);
      expect(ChallengeStatus.waiting.acceptsEvents, isFalse);
      expect(ChallengeStatus.finished.isClosed, isTrue);
      expect(ChallengeStatus.cancelled.isClosed, isTrue);
      expect(ChallengeStatus.active.isClosed, isFalse);
    });

    test('fromId tolera valores desconocidos', () {
      expect(ChallengeStatus.fromId('active'), ChallengeStatus.active);
      expect(ChallengeStatus.fromId('???'), ChallengeStatus.cancelled);
      expect(ChallengeVisibility.fromId(null), ChallengeVisibility.private);
    });
  });

  group('Challenge', () {
    test('host, participantes, cupo y título', () {
      final c = challengeWith(participants: ['a', 'b'], max: 2);
      expect(c.isHost('a'), isTrue);
      expect(c.isHost('b'), isFalse);
      expect(c.isHost(null), isFalse);
      expect(c.isParticipant('b'), isTrue);
      expect(c.isParticipant('z'), isFalse);
      expect(c.isFull, isTrue);
      expect(c.spotsLeft, 0);
      expect(c.displayTitle('Alitas'), 'Reto de Alitas');
      expect(c.displayTitle(null), 'Reto');
    });
  });

  group('tallyEvents', () {
    test('reconstruye los totales por usuario', () {
      final totals = tallyEvents([
        eventFor('a'),
        eventFor('a'),
        eventFor('b'),
        eventFor('a', type: ChallengeEventType.decrement),
      ]);
      expect(totals, {'a': 1, 'b': 1});
    });

    test('ignora eventos repetidos (mismo clientEventId)', () {
      final e = eventFor('a');
      expect(tallyEvents([e, e, e]), {'a': 1});
    });
  });

  group('rankEntries', () {
    test('ordena de mayor a menor con medallas', () {
      final ranked = rankEntries([entry('a', 3), entry('b', 7), entry('c', 5)]);
      expect([for (final r in ranked) r.entry.userId], ['b', 'c', 'a']);
      expect([for (final r in ranked) r.position], [1, 2, 3]);
      expect([for (final r in ranked) r.medal], ['🥇', '🥈', '🥉']);
    });

    test('los empates comparten posición (1, 1, 3) sin desempate', () {
      final ranked = rankEntries([
        entry('a', 5, name: 'Beto'),
        entry('b', 5, name: 'Ana'),
        entry('c', 2),
        entry('d', 1),
      ]);
      expect([for (final r in ranked) r.position], [1, 1, 3, 4]);
      expect([for (final r in ranked) r.medal], ['🥇', '🥇', '🥉', '']);
    });

    test('todos empatados en 0 son primeros', () {
      final ranked = rankEntries([entry('a', 0), entry('b', 0)]);
      expect([for (final r in ranked) r.position], [1, 1]);
    });

    test('total del resultado', () {
      final result = ChallengeResult(
        challengeId: 'c1',
        hostUserId: 'a',
        categoryId: 'alitas',
        entries: [entry('a', 4), entry('b', 6)],
      );
      expect(result.total, 10);
      expect(result.participantIds, ['a', 'b']);
    });
  });

  group('InviteCode.generate', () {
    test('6 caracteres válidos, sin ambiguos', () {
      final rng = Random(42);
      for (var i = 0; i < 500; i++) {
        final code = InviteCode.generate(rng);
        expect(code.length, 6);
        expect(InviteCode.isValid(code), isTrue, reason: code);
        expect(code, isNot(matches(RegExp('[01OIL]'))));
      }
    });

    test('normaliza la entrada del usuario', () {
      expect(InviteCode.normalize('ab23cd'), 'AB23CD');
      expect(InviteCode.normalize('AB 23CD'), 'AB23CD');
      expect(InviteCode.isValid('ab23cd'), isTrue);
    });
  });

  group('ClientEventId', () {
    test('20 alfanuméricos y distintos', () {
      final ids = {for (var i = 0; i < 1000; i++) ClientEventId.generate()};
      expect(ids.length, 1000);
      expect(ids.every(ClientEventId.isValid), isTrue);
      expect(ClientEventId.isValid('corto'), isFalse);
      expect(ClientEventId.isValid('a' * 19 + '/'), isFalse);
    });
  });
}
