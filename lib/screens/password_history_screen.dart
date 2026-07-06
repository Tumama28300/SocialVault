import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../models/password_history_entry.dart';
import '../models/social_network.dart';
import '../services/vault_service.dart';

class PasswordHistoryScreen extends StatefulWidget {
  final SocialNetwork network;

  const PasswordHistoryScreen({super.key, required this.network});

  @override
  State<PasswordHistoryScreen> createState() => _PasswordHistoryScreenState();
}

class _PasswordHistoryScreenState extends State<PasswordHistoryScreen> {
  final VaultService _vaultService = VaultService();
  List<PasswordHistoryEntry> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final history = await _vaultService.getHistory(widget.network.id);
    if (!mounted) return;
    setState(() {
      _history = history;
      _isLoading = false;
    });
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return "$day/$month/${date.year} a les $hour:$minute";
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(
              widget.network.icon,
              color: widget.network.brandColor,
              size: 20,
            ),
            const SizedBox(width: 10),
            const Flexible(
              child: Text('Historial', overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : (_history.isEmpty
                ? _buildEmptyState(colors)
                : ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: _history.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final entry = _history[index];
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: colors.outlineVariant),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entry.password,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      letterSpacing: 1,
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _formatDate(entry.savedAt),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Copiar',
                              icon: const Icon(Icons.copy_rounded),
                              onPressed: () async {
                                final messenger = ScaffoldMessenger.of(context);
                                await Clipboard.setData(
                                  ClipboardData(text: entry.password),
                                );
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('Contrasenya copiada!'),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  )),
    );
  }

  Widget _buildEmptyState(ColorScheme colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.history_rounded,
              size: 56,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              "Encara no hi ha contrasenyes anteriors per a ${widget.network.name}.",
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Text(
              "Apareixeran aquí cada cop que en generis una de nova.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
