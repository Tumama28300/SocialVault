import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'dart:math';

import '../services/vault_service.dart';
import '../models/social_network.dart';
import 'password_history_screen.dart';

const _successColor = Color(0xFF34D399);

class NetworkVaultScreen extends StatefulWidget {
  final SocialNetwork network;

  const NetworkVaultScreen({super.key, required this.network});

  @override
  State<NetworkVaultScreen> createState() => _NetworkVaultScreenState();
}

class _NetworkVaultScreenState extends State<NetworkVaultScreen> {
  final VaultService _vaultService = VaultService();

  bool _isLoading = true;
  bool _isLocked = false;
  bool _justUnlocked = false;
  String _currentPassword = "";

  bool _step2Completed = false;
  late DateTime _targetUnlockTime;
  DateTime? _unlockTime;
  Timer? _timer;
  Duration _timeLeft = Duration.zero;

  SocialNetwork get _network => widget.network;

  @override
  void initState() {
    super.initState();
    _targetUnlockTime = _getNextSaturdayMorning();
    _loadSavedState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // --- LÒGICA DE NEGOCI ---

  Future<void> _loadSavedState() async {
    final state = await _vaultService.loadState(_network.id);
    DateTime now = DateTime.now();

    if (state['password'].isNotEmpty) {
      _currentPassword = state['password'];
    }

    if (state['isLocked'] == true && state['unlockTime'] != null) {
      DateTime savedTime = state['unlockTime'];

      if (savedTime.isAfter(now)) {
        _isLocked = true;
        _unlockTime = savedTime;
        _startTimer();
      } else {
        await _unlockVault();
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _generatePassword() async {
    const chars =
        'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890!@#\$%^&*()';
    Random rnd = Random.secure();
    String newPassword = String.fromCharCodes(
      Iterable.generate(16, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))),
    );

    setState(() {
      _currentPassword = newPassword;
      _step2Completed = false;
      _targetUnlockTime = _getNextSaturdayMorning();
    });

    // Si ja hi havia una contrasenya activa, queda arxivada a l'historial
    // abans de sobreescriure-la.
    await _vaultService.saveDraft(
      networkId: _network.id,
      password: newPassword,
    );
  }

  Future<void> _selectUnlockTime(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _targetUnlockTime.isBefore(DateTime.now())
          ? DateTime.now().add(const Duration(days: 1))
          : _targetUnlockTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'TRIA QUIN DIA ES DESBLOQUEJARÀ',
      cancelText: 'CANCEL·LAR',
      confirmText: 'ACCEPTAR',
    );

    if (pickedDate != null) {
      if (!context.mounted) return;

      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_targetUnlockTime),
        helpText: 'A QUINA HORA?',
        cancelText: 'CANCEL·LAR',
        confirmText: 'ACCEPTAR',
      );

      if (pickedTime != null) {
        setState(() {
          _targetUnlockTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  Future<void> _lockVault() async {
    DateTime targetTime = _targetUnlockTime;

    if (targetTime.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: La data de bloqueig ha de ser futura!'),
        ),
      );
      return;
    }

    await _vaultService.saveLockState(
      networkId: _network.id,
      isLocked: true,
      unlockTime: targetTime,
      password: _currentPassword,
    );

    setState(() {
      _isLocked = true;
      _unlockTime = targetTime;
    });

    _startTimer();
  }

  Future<void> _unlockVault() async {
    await _vaultService.unlockVault(_network.id);
    setState(() {
      _isLocked = false;
      _justUnlocked = true;
      _timeLeft = Duration.zero;
      _step2Completed = false;
    });
  }

  DateTime _getNextSaturdayMorning() {
    DateTime now = DateTime.now();
    int daysUntilSaturday = (6 - now.weekday) % 7;

    if (daysUntilSaturday == 0 && now.hour >= 10) {
      daysUntilSaturday = 7;
    }

    DateTime nextSaturday = now.add(Duration(days: daysUntilSaturday));
    return DateTime(
      nextSaturday.year,
      nextSaturday.month,
      nextSaturday.day,
      10,
      0,
      0,
    );
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now();
      if (_unlockTime!.isBefore(now)) {
        _unlockVault();
        timer.cancel();
      } else {
        setState(() {
          _timeLeft = _unlockTime!.difference(now);
        });
      }
    });
  }

  // --- INTERFÍCIE D'USUARI (UI) ---

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(_network.icon, color: _network.brandColor, size: 20),
            const SizedBox(width: 10),
            Flexible(
              child: Text(_network.name, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        centerTitle: true,
        // Mentre la caixa forta està segellada, l'historial de contrasenyes
        // roman amagat: si l'objectiu és no poder-hi accedir, mostrar-lo
        // seria una escletxa per saltar-se el bloqueig.
        actions: [
          if (!_isLocked)
            IconButton(
              tooltip: 'Historial de contrasenyes',
              icon: const Icon(Icons.history_rounded),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PasswordHistoryScreen(network: _network),
                  ),
                );
              },
            ),
        ],
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [colors.primary.withValues(alpha: 0.08), colors.surface],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : (_isLocked
                        ? _buildLockedState(colors)
                        : (_justUnlocked
                              ? _buildJustUnlockedState(colors)
                              : _buildUnlockedState(colors))),
            ),
          ),
        ),
      ),
    );
  }

  Widget _stepHeader(ColorScheme colors, String number, String title) {
    return Row(
      children: [
        CircleAvatar(
          radius: 13,
          backgroundColor: colors.primary,
          child: Text(
            number,
            style: TextStyle(
              color: colors.onPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ],
    );
  }

  Widget _buildUnlockedState(ColorScheme colors) {
    String formattedDate =
        "${_targetUnlockTime.day.toString().padLeft(2, '0')}/${_targetUnlockTime.month.toString().padLeft(2, '0')}/${_targetUnlockTime.year}";
    String formattedTime =
        "${_targetUnlockTime.hour.toString().padLeft(2, '0')}:${_targetUnlockTime.minute.toString().padLeft(2, '0')}";

    return ListView(
      shrinkWrap: true,
      children: [
        Icon(Icons.lock_open_rounded, size: 64, color: _successColor),
        const SizedBox(height: 12),
        Center(
          child: Text(
            "Desbloquejat",
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 28),

        _stepHeader(colors, "1", "Genera una contrasenya nova"),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: _generatePassword,
          icon: const Icon(Icons.autorenew_rounded),
          label: const Text('Generar contrasenya'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        const SizedBox(height: 20),

        if (_currentPassword.isNotEmpty) ...[
          _stepHeader(colors, "2", "Copia-la a ${_network.name}"),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            alignment: Alignment.center,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: Text(
              _currentPassword,
              style: const TextStyle(
                fontSize: 22,
                letterSpacing: 1.5,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(height: 12),

          FilledButton.tonalIcon(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              await Clipboard.setData(ClipboardData(text: _currentPassword));

              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    'Copiada! Obrint pàgina de ${_network.name}...',
                  ),
                  backgroundColor: _successColor,
                ),
              );

              setState(() {
                _step2Completed = true;
              });

              // Forcem un Custom Tab / SFSafariViewController amb
              // inAppBrowserView: així el SO no intenta redirigir la URL
              // cap a l'app nativa (que ignoraria la ruta de canvi de
              // contrasenya i obriria el feed normal).
              final Uri url = Uri.parse(_network.passwordChangeUrl);
              await launchUrl(url, mode: LaunchMode.inAppBrowserView);
            },
            icon: FaIcon(_network.icon, size: 18),
            label: Text('Copiar i obrir ${_network.name}'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),

          const SizedBox(height: 28),

          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: _step2Completed ? 1.0 : 0.4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _stepHeader(colors, "3", "Tria quan es desbloquejarà"),
                const SizedBox(height: 10),
                Material(
                  color: colors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: _step2Completed
                        ? () => _selectUnlockTime(context)
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_month_rounded,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 12),
                          Text("$formattedDate a les $formattedTime"),
                          const Spacer(),
                          const Icon(Icons.edit_rounded, size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                FilledButton.icon(
                  onPressed: _step2Completed ? () => _lockVault() : null,
                  icon: const Icon(Icons.lock_rounded),
                  label: const Text('Segellar caixa forta'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    backgroundColor: _step2Completed
                        ? colors.error
                        : colors.surfaceContainerHighest,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildJustUnlockedState(ColorScheme colors) {
    return ListView(
      shrinkWrap: true,
      children: [
        Icon(Icons.lock_open_rounded, size: 64, color: _successColor),
        const SizedBox(height: 16),
        Center(
          child: Text(
            "S'ha desbloquejat!",
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: Text(
            "Contrasenya segellada per a ${_network.name}",
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _successColor.withValues(alpha: 0.4)),
          ),
          child: Text(
            _currentPassword,
            style: const TextStyle(
              fontSize: 22,
              letterSpacing: 1.5,
              fontFamily: 'monospace',
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            await Clipboard.setData(ClipboardData(text: _currentPassword));
            messenger.showSnackBar(
              const SnackBar(
                content: Text('Contrasenya copiada!'),
                backgroundColor: _successColor,
              ),
            );
          },
          icon: const Icon(Icons.copy_rounded),
          label: const Text('Copiar contrasenya'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        const SizedBox(height: 28),
        const Divider(),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () {
            setState(() {
              _justUnlocked = false;
              _step2Completed = false;
              _targetUnlockTime = _getNextSaturdayMorning();
            });
          },
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Configurar un nou bloqueig'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLockedState(ColorScheme colors) {
    String days = _timeLeft.inDays.toString().padLeft(2, '0');
    String hours = (_timeLeft.inHours % 24).toString().padLeft(2, '0');
    String minutes = (_timeLeft.inMinutes % 60).toString().padLeft(2, '0');
    String seconds = (_timeLeft.inSeconds % 60).toString().padLeft(2, '0');

    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.errorContainer.withValues(alpha: 0.4),
            ),
            child: Icon(Icons.lock_rounded, size: 72, color: colors.error),
          ),
          const SizedBox(height: 24),
          Text(
            "ACCÉS DENEGAT",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: colors.error,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Fins que s'acabi el temps, gaudeix de la vida real.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 36),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 26),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors.error.withValues(alpha: 0.35)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildTimeColumn(colors, days, "Dies"),
                _timeSeparator(colors),
                _buildTimeColumn(colors, hours, "Hores"),
                _timeSeparator(colors),
                _buildTimeColumn(colors, minutes, "Min"),
                _timeSeparator(colors),
                _buildTimeColumn(colors, seconds, "Seg"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeSeparator(ColorScheme colors) {
    return Text(
      ":",
      style: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.bold,
        color: colors.onSurfaceVariant,
      ),
    );
  }

  Widget _buildTimeColumn(ColorScheme colors, String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
        ),
      ],
    );
  }
}
