import 'package:flutter_test/flutter_test.dart';
import 'package:foodreto/core/error/result.dart';
import 'package:foodreto/core/utils/text_normalizer.dart';
import 'package:foodreto/features/restaurant/data/models/restaurant_dto.dart';
import 'package:foodreto/features/restaurant/data/repositories/in_memory_restaurant_repository.dart';
import 'package:foodreto/features/restaurant/domain/entities/restaurant.dart';

void main() {
  group('TextNormalizer', () {
    test('normaliza acentos, mayúsculas y signos', () {
      expect(TextNormalizer.normalize('  Wing  HOUSE! '), 'wing house');
      expect(TextNormalizer.normalize('Pollos Ñandú'), 'pollos nandu');
    });

    test('slugify', () {
      expect(
        TextNormalizer.slugify('Hot Dogs de Tío Pepe'),
        'hot-dogs-de-tio-pepe',
      );
    });
  });

  test('RestaurantDto calcula slug y nombre normalizado si faltan', () {
    final restaurant = RestaurantDto.fromMap('r1', {
      'name': 'Wing House',
      'city': 'Santo Domingo',
      'country': 'do',
      'latitude': 18.47,
      'longitude': -69.9,
    })!;
    expect(restaurant.slug, 'wing-house');
    expect(restaurant.normalizedName, 'wing house');
    expect(restaurant.country, 'DO');
    expect(restaurant.hasLocation, isTrue);
    expect(RestaurantDto.fromMap('r2', {'city': 'x'}), isNull);
  });

  test('búsqueda por prefijo solo devuelve activos', () async {
    final repository = InMemoryRestaurantRepository(const [
      Restaurant(
        id: '1',
        name: 'Wing House',
        slug: 'wing-house',
        normalizedName: 'wing house',
        city: 'SD',
        country: 'DO',
      ),
      Restaurant(
        id: '2',
        name: 'Wings & Co',
        slug: 'wings-co',
        normalizedName: 'wings co',
        city: 'SD',
        country: 'DO',
        isActive: false,
      ),
      Restaurant(
        id: '3',
        name: 'Sushi House',
        slug: 'sushi-house',
        normalizedName: 'sushi house',
        city: 'SD',
        country: 'DO',
      ),
    ]);
    final result = await repository.searchByName('WÍNG');
    expect((result as Success<List<Restaurant>>).value.map((r) => r.id), ['1']);
    expect(((await repository.getBySlug('wings-co')) as Success).value, isNull);
  });
}
