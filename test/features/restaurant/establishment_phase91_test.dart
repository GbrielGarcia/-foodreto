import 'package:flutter_test/flutter_test.dart';
import 'package:foodreto/core/error/result.dart';
import 'package:foodreto/core/utils/text_normalizer.dart';
import 'package:foodreto/features/notifications/domain/entities/notification_type.dart';
import 'package:foodreto/features/restaurant/data/models/restaurant_dto.dart';
import 'package:foodreto/features/restaurant/data/repositories/in_memory_restaurant_repository.dart';
import 'package:foodreto/features/restaurant/domain/entities/establishment_status.dart';
import 'package:foodreto/features/restaurant/domain/repositories/restaurant_repository.dart';

T _value<T>(Result<T> r) =>
    r.fold(onSuccess: (v) => v, onFailure: (f) => throw f);

void main() {
  group('EstablishmentStatus', () {
    test('fromId and discoverability', () {
      expect(
        EstablishmentStatus.fromId('pending'),
        EstablishmentStatus.pending,
      );
      expect(EstablishmentStatus.approved.isPubliclyDiscoverable, isTrue);
      expect(EstablishmentStatus.pending.isPubliclyDiscoverable, isFalse);
    });

    test('unknown id defaults to approved', () {
      expect(
        EstablishmentStatus.fromId('unknown'),
        EstablishmentStatus.approved,
      );
    });
  });

  group('RestaurantDto migration', () {
    test('status field drives isActive', () {
      final pending = RestaurantDto.fromMap('p', {
        'name': 'Cafe',
        'city': 'Quito',
        'country': 'EC',
        'status': 'pending',
        'creatorUserId': 'u1',
        'ownerUserId': 'u1',
        'isActive': false,
      })!;
      expect(pending.status, EstablishmentStatus.pending);
      expect(pending.isActive, isFalse);

      final legacy = RestaurantDto.fromMap('l', {
        'name': 'Legacy',
        'city': 'Quito',
        'country': 'EC',
        'isActive': true,
      })!;
      expect(legacy.status, EstablishmentStatus.approved);
      expect(legacy.isActive, isTrue);
    });

    test('toCreateRequestMap pending ownership', () {
      final map = RestaurantDto.toCreateRequestMap(
        name: 'Wing House',
        city: 'Quito',
        country: 'ec',
        creatorUid: 'user-a',
      );
      expect(map['status'], 'pending');
      expect(map['isActive'], false);
      expect(map['creatorUserId'], 'user-a');
      expect(map['ownerUserId'], 'user-a');
    });
  });

  group('NotificationType establishment', () {
    test('tryParse new types', () {
      expect(
        NotificationType.tryParse('establishmentApproved'),
        NotificationType.establishmentApproved,
      );
      expect(
        NotificationType.tryParse('establishmentRejected'),
        NotificationType.establishmentRejected,
      );
      expect(NotificationType.establishmentApproved.isOfficial, isTrue);
    });
  });

  group('InMemoryRestaurantRepository 9.1', () {
    late InMemoryRestaurantRepository repo;

    setUp(() {
      repo = InMemoryRestaurantRepository();
    });

    test('createRequest and listMine', () async {
      final id = _value(
        await repo.createRequest(
          const CreateEstablishmentRequest(
            name: 'Taco Place',
            city: 'Quito',
            country: 'EC',
            creatorUid: 'u1',
          ),
        ),
      );
      expect(id, isNotEmpty);
      final mine = _value(await repo.listMine('u1'));
      expect(mine, hasLength(1));
      expect(mine.first.status, EstablishmentStatus.pending);
      expect(mine.first.creatorUserId, 'u1');
      expect(mine.first.ownerUserId, 'u1');
    });

    test('creatorUserId immutable on owner update', () async {
      final id = _value(
        await repo.createRequest(
          const CreateEstablishmentRequest(
            name: 'Burger',
            city: 'Guayaquil',
            country: 'EC',
            creatorUid: 'creator-1',
          ),
        ),
      );
      await repo.updateOwnerFields(
        id: id,
        ownerUid: 'creator-1',
        update: const OwnerEstablishmentUpdate(name: 'Burger XL'),
      );
      final mine = _value(await repo.listMine('creator-1'));
      expect(mine.first.name, 'Burger XL');
      expect(mine.first.creatorUserId, 'creator-1');
      expect(
        mine.first.normalizedName,
        TextNormalizer.normalize('Burger XL'),
      );
    });

    test('findPossibleDuplicates', () async {
      await repo.createRequest(
        const CreateEstablishmentRequest(
          name: 'Wing House',
          city: 'Quito',
          country: 'EC',
          creatorUid: 'u1',
        ),
      );
      final dupes = _value(
        await repo.findPossibleDuplicates('wing house', 'Quito'),
      );
      expect(dupes, hasLength(1));
    });

    test('listByStatus pending', () async {
      await repo.createRequest(
        const CreateEstablishmentRequest(
          name: 'Pending Only',
          city: 'Cuenca',
          country: 'EC',
          creatorUid: 'u2',
        ),
      );
      final page = _value(
        await repo.listByStatus(EstablishmentStatus.pending),
      );
      expect(page.items, hasLength(1));
      expect(page.items.first.name, 'Pending Only');
    });

    test('9.2 owner contact gallery and videos', () async {
      final id = _value(
        await repo.createRequest(
          const CreateEstablishmentRequest(
            name: 'Sushi Spot',
            city: 'Quito',
            country: 'EC',
            creatorUid: 'owner-1',
          ),
        ),
      );
      await repo.updateOwnerFields(
        id: id,
        ownerUid: 'owner-1',
        update: const OwnerEstablishmentUpdate(
          phone: '+593999',
          whatsapp: '+593999',
          instagramUrl: 'https://instagram.com/sushispot',
          galleryUrls: ['https://cdn.example/a.jpg'],
          videoUrls: ['https://youtube.com/watch?v=abc'],
        ),
      );
      final mine = _value(await repo.listMine('owner-1'));
      expect(mine.first.phone, '+593999');
      expect(mine.first.instagramUrl, contains('instagram'));
      expect(mine.first.galleryUrls, hasLength(1));
      expect(mine.first.videoUrls, hasLength(1));
      expect(mine.first.hasContact, isTrue);
    });
  });

  group('RestaurantDto 9.2', () {
    test('parses contact gallery video fields', () {
      final r = RestaurantDto.fromMap('x', {
        'name': 'Local',
        'city': 'Quito',
        'country': 'EC',
        'status': 'approved',
        'phone': '099',
        'galleryUrls': ['https://a.com/1.jpg', 'not-a-url', 'https://a.com/2.jpg'],
        'videoUrls': ['https://youtu.be/z'],
      })!;
      expect(r.phone, '099');
      expect(r.galleryUrls, ['https://a.com/1.jpg', 'https://a.com/2.jpg']);
      expect(r.videoUrls, ['https://youtu.be/z']);
      expect(r.canOwnerManage('u1'), isFalse); // no ownerUserId
    });
  });
}
