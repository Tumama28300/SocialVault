import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../models/social_network.dart';
import '../services/vault_service.dart';
import 'network_vault_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final VaultService _vaultService = VaultService();
  final Map<String, Map<String, dynamic>> _states = {};
  bool _isLoading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadAll();
    // Refresquem el compte enrere de la llista cada minut; el detall de
    // cada xarxa ja té el seu propi cronòmetre en segons.
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _loadAll();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAll() async {
    for (final network in supportedNetworks) {
      _states[network.id] = await _vaultService.loadState(network.id);
    }
    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }

  String _describeStatus(Map<String, dynamic>? state) {
    if (state == null) return '';
    final bool isLocked = state['isLocked'] == true;
    final DateTime? unlockTime = state['unlockTime'];

    if (isLocked && unlockTime != null && unlockTime.isAfter(DateTime.now())) {
      final remaining = unlockTime.difference(DateTime.now());
      if (remaining.inDays > 0) {
        return 'Bloquejat · falten ${remaining.inDays}d ${remaining.inHours % 24}h';
      } else if (remaining.inHours > 0) {
        return 'Bloquejat · falten ${remaining.inHours}h ${remaining.inMinutes % 60}min';
      } else {
        return 'Bloquejat · falten ${remaining.inMinutes}min';
      }
    }

    final String password = (state['password'] as String?) ?? '';
    if (password.isNotEmpty) {
      return 'Desbloquejat · configuració pendent de segellar';
    }
    return 'Desbloquejat';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Social Vault'), centerTitle: true),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [colors.primary.withValues(alpha: 0.08), colors.surface],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: supportedNetworks.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final network = supportedNetworks[index];
                    final state = _states[network.id];
                    final bool isLocked =
                        state != null &&
                        state['isLocked'] == true &&
                        (state['unlockTime'] as DateTime?)?.isAfter(
                              DateTime.now(),
                            ) ==
                            true;

                    return Material(
                      color: colors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(18),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  NetworkVaultScreen(network: network),
                            ),
                          );
                          _loadAll();
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: network.brandColor.withValues(
                                    alpha: 0.16,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: FaIcon(
                                  network.icon,
                                  color: network.brandColor,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      network.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _describeStatus(state),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isLocked
                                            ? colors.error
                                            : colors.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                isLocked
                                    ? Icons.lock_rounded
                                    : Icons.lock_open_rounded,
                                color: isLocked ? colors.error : _successColor,
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.chevron_right_rounded),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

const _successColor = Color(0xFF34D399);
