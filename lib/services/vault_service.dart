import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/password_history_entry.dart';

const int _maxHistoryEntries = 20;

/// Aquest servei s'encarrega ÚNICAMENT de guardar i llegir dades xifrades.
/// Hem separat aquesta lògica de la interfície visual.
///
/// Cada xarxa social (identificada pel seu `networkId`) té el seu propi
/// bloqueig independent: bloquejar Instagram no afecta gens l'estat de
/// TikTok o X.
class VaultService {
  final _storage = const FlutterSecureStorage();

  String _key(String networkId, String field) => '${networkId}_$field';

  // Guarda l'estat de bloqueig d'una xarxa concreta.
  Future<void> saveLockState({
    required String networkId,
    required bool isLocked,
    required DateTime unlockTime,
    required String password,
  }) async {
    await _storage.write(
      key: _key(networkId, 'isLocked'),
      value: isLocked.toString(),
    );
    await _storage.write(
      key: _key(networkId, 'unlockTime'),
      value: unlockTime.toIso8601String(),
    );
    await _storage.write(key: _key(networkId, 'password'), value: password);
  }

  // Allibera el bloqueig d'una xarxa concreta.
  Future<void> unlockVault(String networkId) async {
    await _storage.write(key: _key(networkId, 'isLocked'), value: 'false');
  }

  // Guarda la contrasenya a l'instant, abans de segellar la caixa forta.
  // Així no es perd si l'app es tanca pel camí (per exemple en tornar del
  // navegador després de canviar la contrasenya). Si hi havia una
  // contrasenya anterior diferent, queda arxivada a l'historial.
  Future<void> saveDraft({
    required String networkId,
    required String password,
  }) async {
    final previous = await _storage.read(key: _key(networkId, 'password'));
    if (previous != null && previous.isNotEmpty && previous != password) {
      await _addToHistory(networkId, previous);
    }
    await _storage.write(key: _key(networkId, 'password'), value: password);
  }

  // Llegeix l'estat actual d'una xarxa concreta.
  Future<Map<String, dynamic>> loadState(String networkId) async {
    String? lockedStr = await _storage.read(key: _key(networkId, 'isLocked'));
    String? timeStr = await _storage.read(key: _key(networkId, 'unlockTime'));
    String? passStr = await _storage.read(key: _key(networkId, 'password'));

    return {
      'isLocked': lockedStr == 'true',
      'unlockTime': timeStr != null ? DateTime.parse(timeStr) : null,
      'password': passStr ?? '',
    };
  }

  Future<void> _addToHistory(String networkId, String password) async {
    final history = await getHistory(networkId);
    history.insert(
      0,
      PasswordHistoryEntry(password: password, savedAt: DateTime.now()),
    );
    final trimmed = history.take(_maxHistoryEntries).toList();
    await _storage.write(
      key: _key(networkId, 'history'),
      value: jsonEncode(trimmed.map((e) => e.toJson()).toList()),
    );
  }

  // Retorna l'historial de contrasenyes anteriors d'una xarxa, més recent
  // primer.
  Future<List<PasswordHistoryEntry>> getHistory(String networkId) async {
    final raw = await _storage.read(key: _key(networkId, 'history'));
    if (raw == null || raw.isEmpty) return [];

    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((e) => PasswordHistoryEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
