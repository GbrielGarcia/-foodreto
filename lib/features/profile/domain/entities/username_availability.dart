import '../value_objects/username.dart';

sealed class UsernameAvailability {
  const UsernameAvailability();
}

final class UsernameAvailable extends UsernameAvailability {
  const UsernameAvailable();
}

final class UsernameTaken extends UsernameAvailability {
  const UsernameTaken();
}

/// Es el username actual del propio usuario.
final class UsernameOwned extends UsernameAvailability {
  const UsernameOwned();
}

final class UsernameInvalid extends UsernameAvailability {
  const UsernameInvalid(this.error);
  final UsernameError error;
}
