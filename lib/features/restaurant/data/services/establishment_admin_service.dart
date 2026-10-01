import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Super Admin establecimientos.
///
/// Preferencia: callable Functions (raro = barato). Si Functions no estan
/// desplegadas (`not-found` / `unavailable`), cae a Firestore directo.
class EstablishmentAdminService {
  EstablishmentAdminService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
    this.preferCallables = true,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _functions = functions;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final FirebaseFunctions? _functions;
  final bool preferCallables;

  CollectionReference<Map<String, dynamic>> get _restaurants =>
      _db.collection('restaurants');

  String get _adminUid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('Sesion requerida');
    }
    return uid;
  }

  Future<void> approve(String establishmentId) async {
    final ok = await _tryCallable('approveEstablishment', {
      'establishmentId': establishmentId,
    });
    if (ok) return;
    await _patch(establishmentId, {
      'status': 'approved',
      'isActive': true,
      'approvedAt': FieldValue.serverTimestamp(),
      'approvedByUserId': _adminUid,
      'updatedAt': FieldValue.serverTimestamp(),
      'rejectedAt': FieldValue.delete(),
      'rejectedByUserId': FieldValue.delete(),
      'rejectionReason': FieldValue.delete(),
      'suspendedAt': FieldValue.delete(),
      'suspendedByUserId': FieldValue.delete(),
      'suspensionReason': FieldValue.delete(),
    });
  }

  Future<void> reject(
    String establishmentId, {
    required String reason,
  }) async {
    final trimmed = reason.trim().isEmpty ? 'Sin motivo' : reason.trim();
    final ok = await _tryCallable('rejectEstablishment', {
      'establishmentId': establishmentId,
      'reason': trimmed,
    });
    if (ok) return;
    await _patch(establishmentId, {
      'status': 'rejected',
      'isActive': false,
      'rejectedAt': FieldValue.serverTimestamp(),
      'rejectedByUserId': _adminUid,
      'rejectionReason': trimmed,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> suspend(
    String establishmentId, {
    required String reason,
  }) async {
    final trimmed = reason.trim().isEmpty ? 'Suspendido' : reason.trim();
    final ok = await _tryCallable('suspendEstablishment', {
      'establishmentId': establishmentId,
      'reason': trimmed,
    });
    if (ok) return;
    await _patch(establishmentId, {
      'status': 'suspended',
      'isActive': false,
      'suspendedAt': FieldValue.serverTimestamp(),
      'suspendedByUserId': _adminUid,
      'suspensionReason': trimmed,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> reactivate(String establishmentId) async {
    final ok = await _tryCallable('reactivateEstablishment', {
      'establishmentId': establishmentId,
    });
    if (ok) return;
    await _patch(establishmentId, {
      'status': 'approved',
      'isActive': true,
      'approvedAt': FieldValue.serverTimestamp(),
      'approvedByUserId': _adminUid,
      'updatedAt': FieldValue.serverTimestamp(),
      'suspendedAt': FieldValue.delete(),
      'suspendedByUserId': FieldValue.delete(),
      'suspensionReason': FieldValue.delete(),
    });
  }

  Future<void> transferOwnership(
    String establishmentId, {
    required String newOwnerUserId,
  }) async {
    final next = newOwnerUserId.trim();
    if (next.isEmpty) {
      throw ArgumentError('UID del nuevo owner requerido');
    }
    final ok = await _tryCallable('transferEstablishmentOwnership', {
      'establishmentId': establishmentId,
      'newOwnerUserId': next,
    });
    if (ok) return;
    await _patch(establishmentId, {
      'ownerUserId': next,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<bool> _tryCallable(String name, Map<String, dynamic> data) async {
    final functions = _functions;
    if (!preferCallables || functions == null) return false;
    try {
      await functions.httpsCallable(name).call(data);
      return true;
    } on FirebaseFunctionsException catch (e) {
      // Sin deploy / Blaze / emulador: caer a Firestore.
      if (e.code == 'not-found' ||
          e.code == 'unavailable' ||
          e.code == 'unimplemented') {
        return false;
      }
      rethrow;
    }
  }

  Future<void> _patch(String id, Map<String, dynamic> data) async {
    final ref = _restaurants.doc(id);
    final snap = await ref.get();
    if (!snap.exists) {
      throw StateError('Establecimiento no encontrado');
    }
    await ref.update(data);
  }
}
