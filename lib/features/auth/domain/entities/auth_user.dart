/// Usuario autenticado. Solo identidad; el perfil público vive en `profile`.
class AuthUser {
  const AuthUser({required this.id, required this.email, this.displayName});

  final String id;
  final String? email;
  final String? displayName;

  @override
  bool operator ==(Object other) =>
      other is AuthUser &&
      other.id == id &&
      other.email == email &&
      other.displayName == displayName;

  @override
  int get hashCode => Object.hash(id, email, displayName);
}
