import 'package:google_sign_in/google_sign_in.dart';

/// Obtiene un ID token de Google en Android/iOS para canjearlo en Firebase.
///
/// En web no se usa: Firebase Auth abre su propio popup.
abstract interface class GoogleIdTokenSource {
  bool get isSupported;

  /// Devuelve `null` si el usuario cancela el selector de cuentas.
  Future<String?> requestIdToken();

  Future<void> signOut();
}

class NativeGoogleIdTokenSource implements GoogleIdTokenSource {
  NativeGoogleIdTokenSource({this._iosClientId});

  final String? _iosClientId;
  final GoogleSignIn _google = GoogleSignIn.instance;
  Future<void>? _initialization;

  // En Android el client ID web sale de google-services.json
  // (`default_web_client_id`); en iOS hay que pasarlo explícitamente.
  Future<void> _ensureInitialized() =>
      _initialization ??= _google.initialize(clientId: _iosClientId);

  @override
  bool get isSupported => _google.supportsAuthenticate();

  @override
  Future<String?> requestIdToken() async {
    await _ensureInitialized();
    try {
      final account = await _google.authenticate();
      return account.authentication.idToken;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    await _ensureInitialized();
    await _google.signOut();
  }
}
