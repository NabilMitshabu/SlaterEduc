// Service simple pour récupérer les notifications depuis l'API
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';
import '../auth/user_identity_helper.dart';
import 'eleve_service.dart';

class NotificationService {
  final String baseUrl;
  final Map<String, String> defaultHeaders;
  bool _debug = false;

  NotificationService({this.baseUrl = apiBaseUrl, Map<String, String>? headers, bool debug = false})
      : defaultHeaders = headers ?? {'Content-Type': 'application/json'} {
    _debug = debug;
  }

  void setDebug(bool enabled) => _debug = enabled;

  final UserIdentityHelper _identityHelper = UserIdentityHelper.instance;

  Future<String?> _getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('access_token') ?? prefs.getString('token') ?? prefs.getString('auth_token');
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, String>> _headersWithAuth() async {
    final token = await _getToken();
    final h = Map<String, String>.from(defaultHeaders);
    if (token != null && token.isNotEmpty) h['Authorization'] = 'Bearer $token';
    return h;
  }

  Future<Set<String>> _getLocalReadIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('read_notification_ids') ?? <String>[];
      return list.toSet();
    } catch (_) {
      return <String>{};
    }
  }

  Future<void> _saveLocalReadIds(Set<String> ids) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('read_notification_ids', ids.toList());
    } catch (_) {}
  }

  Future<void> addLocalReadId(String id) async {
    final ids = await _getLocalReadIds();
    ids.add(id);
    await _saveLocalReadIds(ids);
  }

  Future<void> addLocalReadIds(Iterable<String> list) async {
    final ids = await _getLocalReadIds();
    ids.addAll(list);
    await _saveLocalReadIds(ids);
  }

  Future<List<Map<String, dynamic>>> _loadCachedNotifs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('cached_notifications');
      if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];
      final decoded = json.decode(raw);
      if (decoded is List) {
        return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {}
    return <Map<String, dynamic>>[];
  }

  Future<void> _saveCachedNotifs(List<Map<String, dynamic>> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_notifications', json.encode(list));
    } catch (_) {}
  }

  DateTime _parseDate(dynamic v) {
    try {
      if (v == null) return DateTime.fromMillisecondsSinceEpoch(0);
      final s = v.toString();
      final d = DateTime.tryParse(s);
      return d ?? DateTime.fromMillisecondsSinceEpoch(0);
    } catch (_) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
  }

  List<Map<String, dynamic>> _mergeById(List<Map<String, dynamic>> a, List<Map<String, dynamic>> b) {
    final map = <String, Map<String, dynamic>>{};
    void putAll(List<Map<String, dynamic>> src) {
      for (final n in src) {
        final id = (n['id'] ?? n['notification_id'] ?? '').toString();
        if (id.isEmpty) continue;
        map[id] = n;
      }
    }
    putAll(a);
    putAll(b);
    final merged = map.values.toList();
    merged.sort((x, y) => _parseDate(y['created_at'] ?? y['date']).compareTo(_parseDate(x['created_at'] ?? x['date'])));
    // limiter à 500 pour éviter l’explosion du cache
    return merged.length > 500 ? merged.sublist(0, 500) : merged;
  }

  /// Retourne la liste brute des notifications. On peut filtrer côté client
  /// en fonction du champ `id_user` ou `notif_type`.
  Future<List<Map<String, dynamic>>> getAllNotifications() async {
    final headers = await _headersWithAuth();
    final candidates = <String>[
      '$baseUrl/notifications',
      '$baseUrl/notifications/my-notifications',
      '$baseUrl/notifications/my_notifications',
      '$baseUrl/notifications/myNotifications',
    ];

    List<Map<String, dynamic>> remote = <Map<String, dynamic>>[];
    for (final urlStr in candidates) {
      try {
        final url = Uri.parse(urlStr);
        final resp = await http.get(url, headers: headers).timeout(const Duration(seconds: 10));
        if (resp.statusCode == 200) {
          final body = resp.body.trim();
          if (body.isEmpty) break;
          final decoded = json.decode(body);
          if (decoded is List) {
            remote = decoded.map((e) => Map<String, dynamic>.from(e as Map<String, dynamic>)).toList();
            break;
          }
          if (decoded is Map<String, dynamic>) {
            final list = decoded['data'] ?? decoded['results'] ?? decoded['notifications'];
            if (list is List) {
              remote = list.map((e) => Map<String, dynamic>.from(e as Map<String, dynamic>)).toList();
              break;
            }
          }
        }
        if (resp.statusCode == 204) {
          remote = <Map<String, dynamic>>[];
          break;
        }
      } catch (_) {
        // essayer la prochaine route
      }
    }

    // Charger le cache et fusionner
    final cached = await _loadCachedNotifs();
    var merged = _mergeById(cached, remote);

    // Appliquer les lectures locales (si id correspond)
    try {
      final readIds = await _getLocalReadIds();
      if (readIds.isNotEmpty) {
        for (final n in merged) {
          final id = n['id']?.toString();
          if (id != null && readIds.contains(id)) {
            n['is_read'] = true;
          }
        }
      }
    } catch (_) {}

    // Sauvegarder le cache fusionné
    await _saveCachedNotifs(merged);

    return merged;
  }

  /// Récupère les notifications et les filtre (optionnel) par userId.
  Future<List<Map<String, dynamic>>> getNotificationsForUser(String? userId) async {
    final all = await getAllNotifications();
    if (userId == null || userId.isEmpty) return all;
    return all.where((n) {
      final uid = (n['id_user'] ?? n['user_id'] ?? n['idUser'])?.toString();
      return uid == userId;
    }).toList();
  }

  /// Marque une notification comme lue côté serveur. Retourne true si succès.
  Future<bool> markAsRead(String notifId) async {
    final headers = await _headersWithAuth();
    final candidates = <Map<String, String>>[
      {'method': 'POST', 'url': '$baseUrl/notifications/$notifId/read'},
      {'method': 'PATCH', 'url': '$baseUrl/notifications/$notifId/read'},
      {'method': 'PUT', 'url': '$baseUrl/notifications/$notifId/read'},
      {'method': 'POST', 'url': '$baseUrl/notifications/mark-read/$notifId'},
    ];
    bool ok = false;
    for (final c in candidates) {
      try {
        final uri = Uri.parse(c['url']!);
        http.Response resp;
        switch (c['method']) {
          case 'PATCH':
            resp = await http.patch(uri, headers: headers).timeout(const Duration(seconds: 10));
            break;
          case 'PUT':
            resp = await http.put(uri, headers: headers).timeout(const Duration(seconds: 10));
            break;
          default:
            resp = await http.post(uri, headers: headers).timeout(const Duration(seconds: 10));
        }
        if (resp.statusCode == 200 || resp.statusCode == 204) {
          ok = true;
          break;
        }
      } catch (_) {}
    }
    // Persister localement: ids lus + mettre à jour le cache fusionné
    await addLocalReadId(notifId);
    try {
      final cached = await _loadCachedNotifs();
      bool changed = false;
      for (final n in cached) {
        final id = (n['id'] ?? '').toString();
        if (id == notifId) {
          n['is_read'] = true;
          changed = true;
        }
      }
      if (changed) await _saveCachedNotifs(cached);
    } catch (_) {}
    return ok;
  }

  /// Marque toutes les notifications comme lues côté serveur (si l'endpoint existe).
  Future<bool> markAllAsRead() async {
    final headers = await _headersWithAuth();
    final candidates = <Map<String, String>>[
      {'method': 'POST', 'url': '$baseUrl/notifications/mark-all-read'},
      {'method': 'PATCH', 'url': '$baseUrl/notifications/mark_all_read'},
    ];
    bool ok = false;
    for (final c in candidates) {
      try {
        final uri = Uri.parse(c['url']!);
        http.Response resp;
        switch (c['method']) {
          case 'PATCH':
            resp = await http.patch(uri, headers: headers).timeout(const Duration(seconds: 10));
            break;
          default:
            resp = await http.post(uri, headers: headers).timeout(const Duration(seconds: 10));
        }
        if (resp.statusCode == 200 || resp.statusCode == 204) {
          ok = true;
          break;
        }
      } catch (_) {}
    }
    // Persistance locale: marquer toutes comme lues dans le cache
    try {
      final cached = await _loadCachedNotifs();
      for (final n in cached) {
        n['is_read'] = true;
      }
      await _saveCachedNotifs(cached);
    } catch (_) {}
    return ok;
  }

  /// Envoie une notification au serveur (création) pour un utilisateur cible (parent/élève)
  Future<bool> sendNotification({
    required String notifType,
    required String title,
    required String content,
    required String idUser,
  }) async {
    final headers = await _headersWithAuth();
    final payload = {
      'notif_type': notifType,
      'title': title,
      'content': content,
      'id_user': idUser,
    };

    final candidates = <String>[
      '$baseUrl/notifications',
      '$baseUrl/notifications/create',
    ];

    for (final urlStr in candidates) {
      try {
        final url = Uri.parse(urlStr);
        final resp = await http
            .post(url, headers: headers, body: json.encode(payload))
            .timeout(const Duration(seconds: 10));
        if (resp.statusCode == 200 || resp.statusCode == 201) return true;
      } catch (_) {}
    }
    return false;
  }

  Future<String?> getCurrentUserId() async => _identityHelper.getCurrentUserId();
  Future<String?> getCurrentIdUser() async => _identityHelper.getCurrentIdUser();
  void cacheUserId(String? userId) => _identityHelper.cacheUserId(userId);

  Future<Set<String>> getFamilyUserIds() async => _identityHelper.getFamilyUserIds();

  bool isOutgoingMessageNotif(Map<String, dynamic> notif, String myIdUser) {
    try {
      final type = (notif["notif_type"] ?? "").toString().toUpperCase();
      if (type != 'MESSAGE') return false;
      // Déterminer sortant uniquement via des champs "expéditeur" explicites
      final candidates = [
        notif['sender_id'],
      ];
      for (final c in candidates) {
        if (c == null) continue;
        if (c.toString() == myIdUser) return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  bool isAddressedToFamily(Map<String, dynamic> notif, Set<String> familyIds) {
    final dest = (notif['id_user'] ?? notif['user_id'] ?? notif['idUser'])?.toString();
    if (dest != null && dest.isNotEmpty && familyIds.contains(dest)) return true;
    // Si d'autres clés de destination existent, les ajouter ici
    return false;
  }

  List<Map<String, dynamic>> filterIncomingNotifications(
    List<Map<String, dynamic>> list,
    String? myIdUser, {
    bool onlyMessages = false,
    Set<String>? familyIds,
  }) {
    final fam = familyIds ?? <String>{};
    return list.where((n) {
      final type = (n['notif_type'] ?? '').toString().toUpperCase();
      if (onlyMessages && type != 'MESSAGE') return false;

      // Pour MESSAGE: exclure si sortant (envoyé par le parent).
      if (type == 'MESSAGE' && myIdUser != null && myIdUser.isNotEmpty && isOutgoingMessageNotif(n, myIdUser)) {
        return false;
      }

      // Si on dispose de la famille, on garde si la notif vise le parent ou l’enfant.
      if (fam.isNotEmpty) {
        return isAddressedToFamily(n, fam);
      }

      // Par défaut: garder
      return true;
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _fetchRemoteNotifications({
    bool preferIncoming = false,
    String? myIdUser,
    bool onlyMessages = false,
    Set<String>? familyIds, // nouveau: interroger pour chaque id_user connu
  }) async {
    final headers = await _headersWithAuth();

    // Prioriser l’endpoint confirmé quand on cherche l’entrant
    final List<String> baseCandidates = preferIncoming
        ? <String>[
            '$baseUrl/notifications/my-notifications',
            '$baseUrl/notifications/my_notifications',
            '$baseUrl/notifications/myNotifications',
            '$baseUrl/notifications',
          ]
        : <String>[
            '$baseUrl/notifications',
            '$baseUrl/notifications/my-notifications',
            '$baseUrl/notifications/my_notifications',
            '$baseUrl/notifications/myNotifications',
          ];

    // Variantes focalisées: priorité au paramètre exact 'user_id' et potentielle restriction MESSAGE.
    List<String> buildQueries(String id) {
      final encoded = Uri.encodeComponent(id);
      final base = <String>[
        '?user_id=$encoded',
        '?user_id=$encoded&direction=incoming',
        '?user_id=$encoded&incoming_only=true',
      ];
      if (!onlyMessages) return base;
      // Ajouter des variantes pour limiter aux messages si l’API le supporte
      return <String>[
        ...base.map((q) => q + '&notif_type=MESSAGE'),
        ...base.map((q) => q + '&type=MESSAGE'),
        '?user_id=$encoded&notif_type=MESSAGE',
        '?user_id=$encoded&type=MESSAGE',
      ];
    }

    // Construire les variantes de requêtes pour chaque id_user pertinent (moi + famille)
    final Set<String> targetIds = {
      if (myIdUser != null && myIdUser.isNotEmpty) myIdUser,
      ...?familyIds,
    }..removeWhere((e) => e.isEmpty);

    // Si preferIncoming mais sans ids, laisser une variante vide pour récupérer générique
    final List<String> genericQueryVariants = preferIncoming ? <String>[''] : <String>[''];

    if (_debug) {
      print('[NotificationService] preferIncoming=$preferIncoming onlyMessages=$onlyMessages myIdUser=${myIdUser ?? '<null>'}');
      print('[NotificationService] Target ids: ${targetIds.join(', ')}');
      print('[NotificationService] Base candidates (ordered):');
      for (final b in baseCandidates) { print('  - $b'); }
    }

    List<Map<String, dynamic>> remoteAll = <Map<String, dynamic>>[];

    // Itérer sur chaque base et chaque id cible
    for (final base in baseCandidates) {
      bool baseYielded = false;
      if (targetIds.isNotEmpty) {
        for (final id in targetIds) {
          final queries = buildQueries(id);
          for (final q in queries) {
            final urlStr = '$base$q';
            try {
              final url = Uri.parse(urlStr);
              final resp = await http.get(url, headers: headers).timeout(const Duration(seconds: 10));
              if (_debug) print('[NotificationService] GET ${url.toString()} -> ${resp.statusCode}');
              if (resp.statusCode == 200) {
                final body = resp.body.trim();
                if (body.isEmpty) continue;
                final decoded = json.decode(body);
                List<Map<String, dynamic>> chunk = <Map<String, dynamic>>[];
                if (decoded is List) {
                  chunk = decoded.map((e) => Map<String, dynamic>.from(e as Map<String, dynamic>)).toList();
                } else if (decoded is Map<String, dynamic>) {
                  final list = decoded['data'] ?? decoded['results'] ?? decoded['notifications'];
                  if (list is List) {
                    chunk = list.map((e) => Map<String, dynamic>.from(e as Map<String, dynamic>)).toList();
                  }
                }
                if (chunk.isNotEmpty) {
                  remoteAll = _mergeById(remoteAll, chunk);
                  baseYielded = true; // ce base a donné des résultats
                }
              } else if (resp.statusCode == 204) {
                // rien pour cette variante
              }
            } catch (e) {
              if (_debug) print('[NotificationService] GET $urlStr failed: $e');
            }
          }
        }
      }

      // Si aucune id cible ou aucune donnée avec ids, tenter la requête générique
      if (!baseYielded && targetIds.isEmpty) {
        for (final q in genericQueryVariants) {
          final urlStr = '$base$q';
          try {
            final url = Uri.parse(urlStr);
            final resp = await http.get(url, headers: headers).timeout(const Duration(seconds: 10));
            if (_debug) print('[NotificationService] GET ${url.toString()} -> ${resp.statusCode}');
            if (resp.statusCode == 200) {
              final body = resp.body.trim();
              if (body.isEmpty) continue;
              final decoded = json.decode(body);
              List<Map<String, dynamic>> chunk = <Map<String, dynamic>>[];
              if (decoded is List) {
                chunk = decoded.map((e) => Map<String, dynamic>.from(e as Map<String, dynamic>)).toList();
              } else if (decoded is Map<String, dynamic>) {
                final list = decoded['data'] ?? decoded['results'] ?? decoded['notifications'];
                if (list is List) {
                  chunk = list.map((e) => Map<String, dynamic>.from(e as Map<String, dynamic>)).toList();
                }
              }
              if (chunk.isNotEmpty) {
                remoteAll = _mergeById(remoteAll, chunk);
                baseYielded = true;
              }
            }
          } catch (e) {
            if (_debug) print('[NotificationService] GET $urlStr failed: $e');
          }
        }
      }

      // Continuer avec les autres bases pour maximiser la couverture
    }

    // Charger le cache et fusionner
    final cached = await _loadCachedNotifs();
    var merged = _mergeById(cached, remoteAll);

    if (_debug) {
      print('[NotificationService] Remote aggregated: ${remoteAll.length}, Cached: ${cached.length}, Merged: ${merged.length}');
    }

    // Appliquer les lectures locales (si id correspond)
    try {
      final readIds = await _getLocalReadIds();
      if (readIds.isNotEmpty) {
        for (final n in merged) {
          final id = n['id']?.toString();
          if (id != null && readIds.contains(id)) {
            n['is_read'] = true;
          }
        }
      }
    } catch (_) {}

    // Sauvegarder le cache fusionné
    await _saveCachedNotifs(merged);

    return merged;
  }

  Future<Set<String>> _ensureFamilyUserIds(Set<String> current) async {
    // Si on a déjà des ids (parent + potentiellement enfants), conserver
    if (current.isNotEmpty) return current;

    try {
      final eleveService = EleveService();
      final eleves = await eleveService.fetchEleves();
      final ids = <String>{};
      for (final e in eleves) {
        String? idUser = (e['id_user'] ?? e['user_id'])?.toString();
        if ((idUser == null || idUser.isEmpty)) {
          // Tenter de récupérer le détail par id pour obtenir id_user
          final String? eid = (e['id'] ?? e['eleve_id'] ?? e['student_id'])?.toString();
          if (eid != null && eid.isNotEmpty) {
            try {
              final detailed = await eleveService.fetchEleveById(eid);
              final String? du = (detailed['id_user'] ?? detailed['user_id'])?.toString();
              if (du != null && du.isNotEmpty) idUser = du;
            } catch (_) {}
          }
        }
        if (idUser != null && idUser.isNotEmpty) ids.add(idUser);
      }
      // Inclure mon id_user courant
      final me = await getCurrentIdUser();
      if (me != null && me.isNotEmpty) ids.add(me);
      if (ids.isNotEmpty) {
        await _identityHelper.cacheFamilyUserIds(ids);
        return ids;
      }
    } catch (_) {}
    return current;
  }

  Future<List<Map<String, dynamic>>> getIncomingNotificationsForCurrentUser({bool onlyMessages = false, bool preferServer = true}) async {
    final myIdUser = await getCurrentIdUser();
    var family = await getFamilyUserIds();
    // garantir qu’on a les id_user des élèves si possible
    family = await _ensureFamilyUserIds(family);
    if (_debug) print('[NotificationService] Resolved myIdUser=$myIdUser family=${family.join(',')} (onlyMessages=$onlyMessages, preferServer=$preferServer)');

    if (!preferServer) {
      final all = await getAllNotifications();
      final allBefore = all.length;
      final allFiltered = filterIncomingNotifications(all, myIdUser, onlyMessages: onlyMessages, familyIds: family);
      if (_debug) print('[NotificationService] Client-only filter: all=$allBefore -> after filter=${allFiltered.length}');
      return allFiltered;
    }

    // Nouveau: interroger le serveur pour chaque id_user connu
    final mergedPrefer = await _fetchRemoteNotifications(
      preferIncoming: true,
      myIdUser: myIdUser,
      onlyMessages: onlyMessages,
      familyIds: family,
    );
    final before = mergedPrefer.length;
    final filtered = filterIncomingNotifications(mergedPrefer, myIdUser, onlyMessages: onlyMessages, familyIds: family);
    final after = filtered.length;
    if (_debug) print('[NotificationService] Prefer fetch count=$before -> after client filter=$after');
    if (filtered.isNotEmpty || mergedPrefer.isNotEmpty) {
      return filtered;
    }
    final all = await getAllNotifications();
    final allBefore = all.length;
    final allFiltered = filterIncomingNotifications(all, myIdUser, onlyMessages: onlyMessages, familyIds: family);
    if (_debug) print('[NotificationService] Fallback all=$allBefore -> after filter=${allFiltered.length}');
    return allFiltered;
  }
}
