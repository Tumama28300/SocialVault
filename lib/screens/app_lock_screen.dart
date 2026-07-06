import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import 'home_screen.dart';

/// Porta d'entrada a l'app: exigeix biometria (o el PIN/patró del
/// dispositiu) abans de mostrar cap contrasenya. Si el mòbil no té cap
/// mètode de bloqueig configurat, no podem exigir res i deixem passar.
class AppLockScreen extends StatefulWidget {
  const AppLockScreen({super.key});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen>
    with WidgetsBindingObserver {
  final LocalAuthentication _auth = LocalAuthentication();
  bool _isAuthenticated = false;
  bool _isChecking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authenticate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Tornem a exigir l'autenticació quan l'app torna de segon pla, perquè
    // ningú pugui recuperar la sessió simplement agafant el mòbil.
    if (state == AppLifecycleState.paused && _isAuthenticated) {
      setState(() => _isAuthenticated = false);
    } else if (state == AppLifecycleState.resumed && !_isAuthenticated) {
      _authenticate();
    }
  }

  Future<void> _authenticate() async {
    setState(() {
      _isChecking = true;
      _error = null;
    });

    try {
      // local_auth no té implementació per a Flutter Web: no podem exigir
      // cap verificació allà, així que deixem passar directament.
      final bool canAuthenticate =
          !kIsWeb &&
          (await _auth.canCheckBiometrics || await _auth.isDeviceSupported());

      if (!canAuthenticate) {
        setState(() {
          _isAuthenticated = true;
          _isChecking = false;
        });
        return;
      }

      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: 'Desbloqueja Social Vault per continuar',
        biometricOnly: false,
      );

      setState(() {
        _isAuthenticated = didAuthenticate;
        _isChecking = false;
      });
    } catch (_) {
      setState(() {
        _error = 'No s\'ha pogut verificar la teva identitat.';
        _isChecking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isAuthenticated) {
      return const HomeScreen();
    }

    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_person_rounded, size: 72, color: colors.primary),
                const SizedBox(height: 24),
                Text(
                  'Social Vault',
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Verifica la teva identitat per continuar',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.error),
                  ),
                ],
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: _isChecking ? null : _authenticate,
                  icon: const Icon(Icons.fingerprint_rounded),
                  label: Text(_isChecking ? 'Verificant...' : 'Desbloquejar'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
