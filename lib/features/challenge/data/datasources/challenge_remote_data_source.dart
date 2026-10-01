import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/firebase/firestore_collections.dart';

typedef JsonDoc = DocumentReference<Map<String, dynamic>>;
typedef JsonCollection = CollectionReference<Map<String, dynamic>>;

/// Referencias de Firestore de la feature de retos, compartidas por los
/// repositorios de reto, participantes y eventos.
class ChallengeRemoteDataSource {
  const ChallengeRemoteDataSource(this.db);

  final FirebaseFirestore db;

  JsonCollection get challenges =>
      db.collection(FirestoreCollections.challenges);

  JsonCollection get inviteCodes =>
      db.collection(FirestoreCollections.inviteCodes);

  JsonCollection get results =>
      db.collection(FirestoreCollections.challengeResults);

  JsonDoc challenge(String id) => challenges.doc(id);

  JsonCollection participants(String challengeId) => challenge(
    challengeId,
  ).collection(FirestoreCollections.challengeParticipants);

  JsonDoc participant(String challengeId, String uid) =>
      participants(challengeId).doc(uid);

  JsonCollection events(String challengeId) =>
      challenge(challengeId).collection(FirestoreCollections.challengeEvents);
}
