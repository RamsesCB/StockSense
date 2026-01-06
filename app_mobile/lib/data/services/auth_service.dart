import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  AuthService();

  FirebaseAuth get _auth => FirebaseAuth.instance;
  GoogleSignIn get _googleSignIn => GoogleSignIn();
  FacebookAuth get _facebookAuth => FacebookAuth.instance;

  Future<UserCredential?> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      return null;
    }

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    return _auth.signInWithCredential(credential);
  }

  Future<UserCredential?> signInWithFacebook() async {
    final loginResult = await _facebookAuth.login(permissions: ['email']);
    if (loginResult.status != LoginStatus.success) {
      return null;
    }

    final credential = FacebookAuthProvider.credential(
      loginResult.accessToken!.token,
    );
    return _auth.signInWithCredential(credential);
  }
}
