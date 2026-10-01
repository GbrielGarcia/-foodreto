import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../error/failure.dart';

class PermissionFailure extends Failure {
  const PermissionFailure([
    super.message = 'No tienes permiso para realizar esta acción.',
  ]) : super(code: 'permission-denied');
}

/// Traduce errores de Firestore a fallos de dominio.
Failure mapFirestoreError(Object error) {
  if (error is FirebaseException) {
    switch (error.code) {
      case 'permission-denied':
        return const PermissionFailure();
      case 'unavailable':
      case 'deadline-exceeded':
        return const NetworkFailure();
    }
    debugPrint('Firestore: ${error.code} ${error.message}');
  } else {
    debugPrint('Firestore: error inesperado $error');
  }
  return const UnexpectedFailure();
}

DateTime? readTimestamp(Object? value) => switch (value) {
  Timestamp() => value.toDate(),
  DateTime() => value,
  _ => null,
};
