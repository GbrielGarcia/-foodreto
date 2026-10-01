/// Cómo se cuenta una comida. Resultados con unidades distintas nunca se
/// comparan entre sí.
enum UnitType {
  units('unidades', 'unidad'),
  pieces('piezas', 'pieza'),
  portions('porciones', 'porción'),
  plates('platos', 'plato'),
  bowls('bowls', 'bowl'),
  glasses('vasos', 'vaso'),
  bottles('botellas', 'botella'),
  rounds('rondas', 'ronda'),
  orders('pedidos', 'pedido'),
  custom('personalizado', 'personalizado');

  const UnitType(this.plural, this.singular);

  final String plural;
  final String singular;

  /// Valor persistido en Firestore (`units`, `pieces`…).
  String get id => name;

  String label(int amount) => amount == 1 ? singular : plural;

  static UnitType fromId(Object? id) =>
      values.firstWhere((u) => u.id == id, orElse: () => UnitType.units);
}
