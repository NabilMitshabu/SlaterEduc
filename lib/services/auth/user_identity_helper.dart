import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Centralise la résolution de l'identifiant utilisateur actuellement connecté.
class UserIdentityHelper {
  UserIdentityHelper._();

  static final UserIdentityHelper instance = UserIdentityHelper._();
  String? _cachedUserId;
  String? _cachedIdUser; // id_user explicite
  Set<String>? _cachedFamilyIds; // id_user parent + enfants

  /// Retourne l'id utilisateur (id_user) stocké en local ou un identifiant proche.
  /// Explore plusieurs clés possibles pour couvrir les différents flux d'auth.
  Future<String?> getCurrentUserId({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedUserId != null && _cachedUserId!.isNotEmpty) {
      return _cachedUserId;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      String? userId = _readDirectKeys(prefs);
      userId ??= _readFromSerializedUser(prefs);
      _cachedUserId = userId;
      return userId;
    } catch (_) {
      return _cachedUserId;
    }
  }

  /// Retourne explicitement l'id_user (ou user_id) de l'utilisateur courant (parent).
  Future<String?> getCurrentIdUser({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedIdUser != null && _cachedIdUser!.isNotEmpty) {
      return _cachedIdUser;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      // Priorité: id_user -> user_id -> current_user_id (alias courant)
      String? idUser = prefs.getString('id_user')
          ?? prefs.getString('user_id')
          ?? prefs.getString('current_user_id');
      if (idUser == null || idUser.isEmpty) {
        idUser = _readIdUserFromSerializedUser(prefs);
      }
      _cachedIdUser = (idUser != null && idUser.isNotEmpty) ? idUser : null;
      return _cachedIdUser;
    } catch (_) {
      return _cachedIdUser;
    }
  }

  /// Retourne l'ensemble des id_user "famille" (parent + enfants) si disponibles.
  /// Composition: {id_user parent} U prefs['family_user_ids'] U {prefs['current_student_user_id']}.
  Future<Set<String>> getFamilyUserIds({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedFamilyIds != null && _cachedFamilyIds!.isNotEmpty) {
      return _cachedFamilyIds!;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final set = <String>{};
      final parent = await getCurrentIdUser(forceRefresh: forceRefresh);
      if (parent != null && parent.isNotEmpty) set.add(parent);
      final list = prefs.getStringList('family_user_ids') ?? const <String>[];
      set.addAll(list.where((e) => e.isNotEmpty));
      final currentChild = prefs.getString('current_student_user_id');
      if (currentChild != null && currentChild.isNotEmpty) set.add(currentChild);
      _cachedFamilyIds = set;
      return set;
    } catch (_) {
      return _cachedFamilyIds ?? <String>{};
    }
  }

  /// Permet de mettre à jour manuellement le cache (ex: après logout/login).
  void cacheUserId(String? userId) {
    _cachedUserId = (userId != null && userId.isNotEmpty) ? userId : null;
  }

  /// Ajoute/remplace la liste persistée des id_user famille.
  Future<void> cacheFamilyUserIds(Iterable<String> ids) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final set = ids.where((e) => e.isNotEmpty).toSet().toList();
      await prefs.setStringList('family_user_ids', set);
      _cachedFamilyIds = set.toSet();
    } catch (_) {}
  }

  String? _readDirectKeys(SharedPreferences prefs) {
    for (final key in ['current_user_id', 'user_id', 'id_user', 'id']) {
      final value = prefs.getString(key);
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  String? _readFromSerializedUser(SharedPreferences prefs) {
    try {
      final raw = prefs.getString('user');
      if (raw == null || raw.isEmpty) return null;
      final decoded = json.decode(raw);
      if (decoded is Map<String, dynamic>) {
        final possibleKeys = [
          decoded['id'],
          decoded['user_id'],
          decoded['id_user'],
          if (decoded['user'] is Map<String, dynamic>)
            (decoded['user'] as Map<String, dynamic>)['id'],
        ];
        for (final entry in possibleKeys) {
          if (entry == null) continue;
          final value = entry.toString();
          if (value.isNotEmpty) return value;
        }
      }
    } catch (_) {}
    return null;
  }

  String? _readIdUserFromSerializedUser(SharedPreferences prefs) {
    try {
      final raw = prefs.getString('user');
      if (raw == null || raw.isEmpty) return null;
      final decoded = json.decode(raw);
      if (decoded is Map<String, dynamic>) {
        final candidates = <dynamic>[
          decoded['id_user'],
          decoded['user_id'],
          if (decoded['user'] is Map<String, dynamic>)
            (decoded['user'] as Map<String, dynamic>)['id_user'],
          if (decoded['user'] is Map<String, dynamic>)
            (decoded['user'] as Map<String, dynamic>)['user_id'],
        ];
        for (final c in candidates) {
          if (c == null) continue;
          final v = c.toString();
          if (v.isNotEmpty) return v;
        }
      }
    } catch (_) {}
    return null;
  }
}
