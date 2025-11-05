import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ParentService {
  final String baseUrl;

  ParentService({this.baseUrl = 'http://10.251.9.153:8000'});

  /// Récupère le token d'authentification (si présent) depuis SharedPreferences
  Future<String?> _getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // plusieurs clés possibles selon l'implémentation du login
      return prefs.getString('access_token') ?? prefs.getString('token') ?? prefs.getString('auth_token');
    } catch (_) {
      return null;
    }
  }

  List<Map<String, dynamic>>? _parseElevesFromDecoded(dynamic decoded) {
    try {
      if (decoded == null) return null;
      // Si la réponse est directement une liste
      if (decoded is List) {
        return List<Map<String, dynamic>>.from(decoded.map((e) => Map<String, dynamic>.from(e)));
      }

      // Si c'est un objet
      if (decoded is Map<String, dynamic>) {
        // Priorité à la clé 'eleves' (et alternatives)
        if (decoded.containsKey('eleves')) {
          print('ParentService: clé "eleves" trouvée dans la réponse, valeur=${json.encode(decoded['eleves'])}');
          if (decoded['eleves'] is List) {
            return List<Map<String, dynamic>>.from(decoded['eleves'].map((e) => Map<String, dynamic>.from(e)));
          } else {
            print('ParentService: clé "eleves" présente mais n\'est pas une liste.');
            return [];
          }
        }
        if (decoded['children'] is List) {
          return List<Map<String, dynamic>>.from(decoded['children'].map((e) => Map<String, dynamic>.from(e)));
        }
        if (decoded['students'] is List) {
          return List<Map<String, dynamic>>.from(decoded['students'].map((e) => Map<String, dynamic>.from(e)));
        }
        if (decoded['data'] is List) {
          return List<Map<String, dynamic>>.from(decoded['data'].map((e) => Map<String, dynamic>.from(e)));
        }
        if (decoded['results'] is List) {
          return List<Map<String, dynamic>>.from(decoded['results'].map((e) => Map<String, dynamic>.from(e)));
        }
        // Si aucune liste d'élèves n'est trouvée, NE PAS retourner le parent comme élève
      }
    } catch (e) {
      print('ParentService: erreur lors du parsing des eleves: $e');
    }
    return null;
  }

  /// Vérifie si une chaîne est un UUID valide
  bool _isValidUuid(String? id) {
    if (id == null) return false;
    final uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    return uuidRegex.hasMatch(id);
  }

  /// Récupère la liste des élèves liés à un parent donné.
  /// Plusieurs tentatives sont effectuées pour s'adapter aux différentes formes d'API :
  /// 1) GET /parents/{id}/eleves
  /// 2) GET /parents/{id} (rechercher la clé 'eleves')
  /// 3) GET /parents (filtrer par id dans la liste)
  Future<List<Map<String, dynamic>>> getElevesByParentId(String parentId) async {
    if (!_isValidUuid(parentId)) {
      print('ParentService: ERREUR - parentId fourni n\'est pas un UUID valide: $parentId');
      return [];
    }

    final token = await _getToken();
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null && token.isNotEmpty) headers['Authorization'] = 'Bearer $token';

    print('ParentService: fetching eleves for parentId=$parentId using token=${token != null ? '[REDACTED]' : 'none'}');

    // Helper local pour faire une requête GET et tenter d'extraire des élèves
    Future<List<Map<String, dynamic>>?> tryGet(Uri uri) async {
      try {
        final resp = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));
        print('ParentService: GET ${uri.toString()} -> status=${resp.statusCode}');
        if (resp.statusCode == 200) {
          try {
            final dec = json.decode(resp.body);
            print('ParentService: body for ${uri.toString()}: ${resp.body}');
            final parsed = _parseElevesFromDecoded(dec);
            if (parsed != null) return parsed;
            return null;
          } catch (e) {
            print('ParentService: failed to decode body for ${uri.toString()}: $e');
            return null;
          }
        }
        if (resp.statusCode == 404) {
          print('ParentService: 404 for ${uri.toString()}');
          return null;
        }
        if (resp.statusCode == 401) throw Exception('Non autorisé: token invalide ou expiré (401)');
        // autres codes -> on jette pour faire remonter l'erreur
        throw Exception('Erreur HTTP ${resp.statusCode} lors de la requête ${uri.toString()} : ${resp.body}');
      } on TimeoutException catch (_) {
        print('ParentService: timeout for ${uri.toString()}');
        return null;
      } on FormatException catch (e) {
        print('ParentService: format exception for ${uri.toString()}: $e');
        return null;
      } catch (e) {
        print('ParentService: unexpected error for ${uri.toString()}: $e');
        return null;
      }
    };

    // Tentative 1: /parents/{id}/eleves
    final u1 = Uri.parse('$baseUrl/parents/$parentId/eleves');
    final try1 = await tryGet(u1);
    if (try1 != null) return try1;

    // Tentative 2: /parents/{id}
    final u2 = Uri.parse('$baseUrl/parents/$parentId');
    final try2 = await tryGet(u2);
    if (try2 != null) return try2;

    // Tentative 3: /parents (liste) -> filtrer par id
    final u3 = Uri.parse('$baseUrl/parents');
    print('ParentService: falling back to list $u3');
    try {
      final resp3 = await http.get(u3, headers: headers).timeout(const Duration(seconds: 10));
      print('ParentService: GET ${u3.toString()} -> status=${resp3.statusCode}');
      if (resp3.statusCode == 200) {
        print('ParentService: body for fallback /parents: ${resp3.body}');
        final dec3 = json.decode(resp3.body);
        // Si c'est une liste, on filtre
        if (dec3 is List) {
          try {
            final found = dec3.firstWhere((item) {
              if (item is Map) {
                final idCandidate = (item['id_user'] ?? item['id'] ?? item['user_id'])?.toString();
                return idCandidate == parentId || item['id'] == parentId;
              }
              return false;
            }, orElse: () => null);
            if (found != null && found is Map<String, dynamic>) {
              final parsed = _parseElevesFromDecoded(found);
              if (parsed != null) return parsed;
              // Si pas de clé 'eleves', faire une requête supplémentaire sur /parents/{id}/eleves
              final parentDbId = found['id']?.toString();
              if (parentDbId != null && parentDbId.isNotEmpty) {
                print('ParentService: fallback - requête supplémentaire sur /parents/{id}/eleves pour id=$parentDbId');
                final elevesFromApi = await tryGet(Uri.parse('$baseUrl/parents/$parentDbId/eleves'));
                if (elevesFromApi != null) return elevesFromApi;
              }
            }
          } catch (_) {
            // passthrough
          }
        }

        // Si dec3 est un objet avec 'data' ou 'results' contenant la liste
        if (dec3 is Map<String, dynamic>) {
          final listCandidate = dec3['data'] ?? dec3['results'] ?? dec3['parents'] ?? dec3['eleves'];
          if (listCandidate is List) {
            final found = listCandidate.firstWhere((item) {
              if (item is Map) {
                final idCandidate = (item['id'] ?? item['id_user'] ?? item['user_id'])?.toString();
                return idCandidate == parentId;
              }
              return false;
            }, orElse: () => null);
            if (found != null && found is Map<String, dynamic>) {
              final parsed = _parseElevesFromDecoded(found);
              if (parsed != null) return parsed;
            }
          }
        }
      } else if (resp3.statusCode == 401) {
        throw Exception('Non autorisé lors de la récupération de la liste des parents (401)');
      }
    } catch (e) {
      print('ParentService: error during fallback list fetch: $e');
    }

    // Si tout échoue, on renvoie une liste vide (aucun enfant trouvé / endpoint non compatible)
    print('ParentService: no eleves found for parentId=$parentId');
    return [];
  }

  /// Récupère les infos du parent connecté via /parents/{id}/eleves
  Future<Map<String, dynamic>> getParentById(String parentId) async {
    if (!_isValidUuid(parentId)) {
      print('ParentService: ERREUR - parentId fourni n\'est pas un UUID valide: $parentId');
      return {};
    }
    final token = await _getToken();
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null && token.isNotEmpty) headers['Authorization'] = 'Bearer $token';
    final url = '$baseUrl/parents/$parentId/eleves';
    try {
      final resp = await http.get(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 10));
      print('ParentService: GET $url -> status=${resp.statusCode}');
      if (resp.statusCode == 200) {
        final body = json.decode(resp.body);
        if (body is Map) {
          print('ParentService: parent trouvé via /parents/{id}/eleves = ${body.toString()}');
          return Map<String, dynamic>.from(body);
        }
      }
    } catch (e) {
      print('ParentService: erreur API getParentById: $e');
    }
    return {};
  }

  /// Récupère le prénom et le nom du parent via /parents/{id}/eleves
  Future<Map<String, String>> getParentNameById(String parentId) async {
    final parent = await getParentById(parentId);
    final firstName = parent['first_name']?.toString() ?? '';
    final lastName = parent['last_name']?.toString() ?? '';
    return {'first_name': firstName, 'last_name': lastName};
  }

  /// Récupère le parent à partir de l'id_user (user_id)
  Future<Map<String, dynamic>> getParentByUserId(String userId) async {
    final url = '$baseUrl/parents';
    try {
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode == 200) {
        final body = json.decode(resp.body);
        if (body is List) {
          final found = body.firstWhere(
            (item) => item is Map && (item['id_user']?.toString() == userId),
            orElse: () => null,
          );
          if (found != null && found is Map<String, dynamic>) {
            return found;
          }
        }
      }
    } catch (e) {
      print('ParentService: erreur getParentByUserId: $e');
    }
    return {};
  }
}
