import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Instancia de Firestore. Solo se lee en modo Firebase; en tests se
/// sobrescribe con `FakeFirebaseFirestore`.
final firestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);
