import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'home_screen.dart';

class AuthService {
  AuthService();

  // Use getters to avoid immediate access to .instance if Firebase isn't ready
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

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.firebaseReady,
    this.initError,
    this.onRetry,
  });

  final bool firebaseReady;
  final String? initError;
  final VoidCallback? onRetry;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  Future<void> _handleSignIn(
    Future<UserCredential?> Function() provider,
    String providerName,
  ) async {
    if (!widget.firebaseReady) {
      _showSnackBar('Firebase no está inicializado');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final credential = await provider();
      if (!mounted) {
        return;
      }
      final user = credential?.user;
      if (user != null) {
        // Navigate to HomeScreen on success
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else {
        _showSnackBar('Inicio cancelado');
      }
    } on FirebaseAuthException catch (error) {
      _showSnackBar(error.message ?? 'No se pudo conectar con $providerName');
    } catch (_) {
      _showSnackBar('Ocurrió un error con $providerName');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    // Navigate directly to HomeScreen if testing without login (Optional bypass)
    // Uncomment next line to bypass login for UI testing
    // return const HomeScreen();

    final size = MediaQuery.of(context).size;
    // Use the theme colors
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0B1A2A), Color(0xFF1B3B5A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Card(
                  elevation: 12,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: size.width > 500 ? 48 : 32,
                      vertical: 48,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!widget.firebaseReady)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.red.withOpacity(0.35),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Firebase no está configurado',
                                  style: TextStyle(
                                    color: Colors
                                        .red, // Changed to red for visibility on light theme
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (widget.initError != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.initError!,
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                                if (widget.onRetry != null) ...[
                                  const SizedBox(height: 8),
                                  TextButton(
                                    onPressed: _isLoading
                                        ? null
                                        : widget.onRetry,
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.red,
                                    ),
                                    child: const Text(
                                      'Reintentar inicialización',
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        if (!widget.firebaseReady) const SizedBox(height: 24),
                        Text(
                          'Bienvenido a StockSense',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Inicia sesión para continuar',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 36),
                        _AuthButton(
                          icon: Icons.facebook,
                          label: 'Continuar con Facebook',
                          background: const Color(0xFF1877F2),
                          foreground: Colors.white,
                          onPressed: _isLoading
                              ? null
                              : () => _handleSignIn(
                                  _authService.signInWithFacebook,
                                  'Facebook',
                                ),
                        ),
                        const SizedBox(height: 16),
                        _AuthButton(
                          icon: Icons.g_mobiledata,
                          label: 'Continuar con Google',
                          background: Colors.white,
                          foreground: Colors.black,
                          onPressed: _isLoading
                              ? null
                              : () => _handleSignIn(
                                  _authService.signInWithGoogle,
                                  'Google',
                                ),
                        ),
                        const SizedBox(height: 16),
                        _AuthButton(
                          icon: Icons.arrow_forward_rounded,
                          label: 'Ingresar (Saltar Login)',
                          background: const Color(
                            0xFF0F4C75,
                          ), // StockSense Primary Blue
                          foreground: Colors.white,
                          onPressed: () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => const HomeScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.35),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}

class _AuthButton extends StatelessWidget {
  const _AuthButton({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: 30, color: foreground),
      label: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: foreground,
          ),
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        elevation: 1,
      ),
      onPressed: onPressed,
    );
  }
}
