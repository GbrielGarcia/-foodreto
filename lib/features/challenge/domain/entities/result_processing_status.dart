/// Estado del procesamiento oficial del resultado (Functions).
enum ResultProcessingStatus {
  /// Acaba de crearse el documento; aún no hay stats/records.
  pending,

  /// La Function está materializando stats/records/rankings.
  processing,

  /// Stats/records/rankings aplicados de forma idempotente.
  official,

  /// Falló el procesamiento; se puede reprocesar.
  failed,
}
