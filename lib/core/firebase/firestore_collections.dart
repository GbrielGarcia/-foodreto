/// Nombres de colecciones de Firestore (deben coincidir con `firestore.rules`).
abstract final class FirestoreCollections {
  static const users = 'users';
  static const userPrivate = 'private';
  static const userPrivateAccountDoc = 'account';
  static const usernames = 'usernames';
  static const userStatistics = 'userStatistics';
  static const categories = 'categories';
  static const restaurants = 'restaurants';
  static const establishmentAuditLogs = 'establishmentAuditLogs';
  static const establishmentOwnershipTransfers =
      'establishmentOwnershipTransfers';
  static const challenges = 'challenges';
  static const challengeParticipants = 'participants';
  static const challengeEvents = 'events';
  static const challengeResults = 'challengeResults';
  static const inviteCodes = 'inviteCodes';
  static const leaderboards = 'leaderboards';
  static const recordHistory = 'recordHistory';
  static const resultProcessing = 'resultProcessing';
  static const categoryStats = 'categoryStats';
  static const restaurantCategoryStats = 'restaurantCategoryStats';
  static const friendships = 'friendships';
  static const challengeInvitations = 'challengeInvitations';
  static const activities = 'activities';
  static const notifications = 'notifications';
}
