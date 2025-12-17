import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class SchoolService {
  final String baseUrl;
  final Map<String, String> headers;

  SchoolService({this.baseUrl = apiBaseUrl, Map<String, String>? headers})
      : headers = headers ?? {'Content-Type': 'application/json'};

  final Map<String, Map<String, String>> _profCacheByCours = {};
  final Map<String, Map<String, String>> _profCacheByClasse = {};

  /// Fetch list of cours-profs. Try multiple candidate paths to be tolerant to API route differences.
  Future<List<dynamic>> fetchCoursProfs() async {
    final candidates = [
      '$baseUrl/cours/prof',
    ];

    final Map<String, String> outcomes = {};
    for (final urlStr in candidates) {
      try {
        final url = Uri.parse(urlStr);
        final resp = await http.get(url, headers: headers).timeout(const Duration(seconds: 10));
        outcomes[urlStr] = 'status=${resp.statusCode}';
        if (resp.statusCode == 200) {
          final body = resp.body.trim();
          if (body.isEmpty) return <dynamic>[];
          return json.decode(body) as List<dynamic>;
        }
      } catch (e) {
        outcomes[urlStr] = 'error=${e.toString()}';
      }
    }

    final details = outcomes.entries.map((e) => '${e.key} -> ${e.value}').join('; ');
    throw Exception('Failed to fetch coursProfs: none of the endpoints responded 200. Details: $details');
  }

  /// Fetch list of inscriptions
  Future<List<dynamic>> fetchInscriptions() async {
    final url = Uri.parse('$baseUrl/inscriptions');
    final resp = await http.get(url, headers: headers).timeout(const Duration(seconds: 10));
    if (resp.statusCode == 200) {
      return json.decode(resp.body) as List<dynamic>;
    }
    throw Exception('Failed to fetch inscriptions: ${resp.statusCode}');
  }

  /// Fetch list of personnels
  Future<List<dynamic>> fetchPersonnels() async {
    final url = Uri.parse('$baseUrl/personnels');
    final resp = await http.get(url, headers: headers).timeout(const Duration(seconds: 10));
    if (resp.statusCode == 200) {
      return json.decode(resp.body) as List<dynamic>;
    }
    throw Exception('Failed to fetch personnels: ${resp.statusCode}');
  }

  /// Fetch list of users
  Future<List<dynamic>> fetchUsers() async {
    final url = Uri.parse('$baseUrl/users');
    final resp = await http.get(url, headers: headers).timeout(const Duration(seconds: 10));
    if (resp.statusCode == 200) {
      return json.decode(resp.body) as List<dynamic>;
    }
    throw Exception('Failed to fetch users: ${resp.statusCode}');
  }

  /// Fetch list of roles
  Future<List<dynamic>> fetchRoles() async {
    final url = Uri.parse('$baseUrl/roles');
    final resp = await http.get(url, headers: headers).timeout(const Duration(seconds: 10));
    if (resp.statusCode == 200) {
      return json.decode(resp.body) as List<dynamic>;
    }
    throw Exception('Failed to fetch roles: ${resp.statusCode}');
  }

  /// Fetch list of classes
  Future<List<dynamic>> fetchClasses() async {
    final candidates = [
      '$baseUrl/classes',
      '$baseUrl/ecoles/classes',
      '$baseUrl/school/classes',
    ];
    final Map<String, String> outcomes = {};
    for (final urlStr in candidates) {
      try {
        final url = Uri.parse(urlStr);
        final resp = await http.get(url, headers: headers).timeout(const Duration(seconds: 10));
        outcomes[urlStr] = 'status=${resp.statusCode}';
        if (resp.statusCode == 200) {
          final body = resp.body.trim();
          if (body.isEmpty) return <dynamic>[];
          return json.decode(body) as List<dynamic>;
        }
      } catch (e) {
        outcomes[urlStr] = 'error=${e.toString()}';
      }
    }
    final details = outcomes.entries.map((e) => '${e.key} -> ${e.value}').join('; ');
    throw Exception('Failed to fetch classes: none of the endpoints responded 200. Details: $details');
  }

  Future<Map<String, String>?> getProfessorIdentifiers({String? idCours, String? idClasse}) async {
    final keyCours = idCours?.trim();
    final keyClasse = idClasse?.trim();
    if (keyCours != null && _profCacheByCours.containsKey(keyCours)) return _profCacheByCours[keyCours];
    if (keyClasse != null && _profCacheByClasse.containsKey(keyClasse)) return _profCacheByClasse[keyClasse];

    final coursProfs = await fetchCoursProfs();
    String? targetPersonnelId;
    for (final raw in coursProfs) {
      try {
        final Map<String, dynamic> entry = Map<String, dynamic>.from(raw as Map);
        final personnelId = (entry['idPersonnel'] ?? entry['id_personnel'] ?? entry['personnel_id'])?.toString();
        final coursId = (entry['idCours'] ?? entry['id_cours'] ?? entry['cours_id'])?.toString();
        final classeId = (entry['idClasse'] ?? entry['id_classe'] ?? entry['classe_id'])?.toString();
        final matchCours = keyCours != null && coursId != null && coursId == keyCours;
        final matchClasse = keyClasse != null && classeId != null && classeId == keyClasse;
        if ((matchCours || matchClasse) && personnelId != null && personnelId.isNotEmpty) {
          targetPersonnelId = personnelId;
          if (matchCours) {
            _profCacheByCours[keyCours!] = {'personnel_id': personnelId};
          }
          if (matchClasse) {
            _profCacheByClasse[keyClasse!] = {'personnel_id': personnelId};
          }
          break;
        }
      } catch (_) {}
    }
    if (targetPersonnelId == null) return null;

    final personnels = await fetchPersonnels();
    String? userId;
    for (final raw in personnels) {
      try {
        final Map<String, dynamic> personnel = Map<String, dynamic>.from(raw as Map);
        final pid = (personnel['id'] ?? personnel['id_personnel'] ?? personnel['personnel_id'])?.toString();
        if (pid != null && pid == targetPersonnelId) {
          userId = (personnel['idUser'] ?? personnel['id_user'] ?? personnel['user_id'])?.toString();
          if (userId == null && personnel['user'] is Map) {
            final nested = personnel['user'] as Map;
            userId = (nested['id'] ?? nested['user_id'] ?? nested['idUser'])?.toString();
          }
          break;
        }
      } catch (_) {}
    }

    if (userId == null || userId.isEmpty) {
      final users = await fetchUsers();
      for (final raw in users) {
        try {
          final Map<String, dynamic> user = Map<String, dynamic>.from(raw as Map);
          final linkedPersonnel = (user['personnel_id'] ?? user['personnel'] ?? user['meta']?['personnel_id'])?.toString();
          if (linkedPersonnel != null && linkedPersonnel == targetPersonnelId) {
            userId = user['id']?.toString();
            break;
          }
        } catch (_) {}
      }
    }

    final result = {'personnel_id': targetPersonnelId, if (userId != null && userId.isNotEmpty) 'user_id': userId};
    if (keyCours != null) _profCacheByCours[keyCours] = result;
    if (keyClasse != null) _profCacheByClasse[keyClasse] = result;
    return result;
  }

  /// Retourne l'idPersonnel (identifiant interne du personnel) pour un cours donné.
  /// Recherche par idCours puis par idClasse dans la liste renvoyée par /cours/prof.
  Future<String?> getProfessorPersonnelIdForCourse({String? idCours, String? idClasse}) async {
    final identifiers = await getProfessorIdentifiers(idCours: idCours, idClasse: idClasse);
    return identifiers?['personnel_id'];
  }

  /// Résout l'id utilisateur (user id) du professeur pour un cours donné.
  /// 1) récupère l'idPersonnel via `getProfessorPersonnelIdForCourse`
  /// 2) cherche dans `/personnels` pour trouver le champ user (idUser / user_id)
  Future<String?> getProfessorUserIdForCourse({String? idCours, String? idClasse}) async {
    final identifiers = await getProfessorIdentifiers(idCours: idCours, idClasse: idClasse);
    return identifiers?['user_id'];
  }
}
