import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class PresenceService {
  final String baseUrl;
  PresenceService({this.baseUrl = 'http://192.168.1.70:8000'});

  Future<String?> _getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('access_token') ?? prefs.getString('token') ?? prefs.getString('auth_token');
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getSessionsPresence(String idClasse) async {
    final url = Uri.parse('$baseUrl/sessions-presence');
    final token = await _getToken();
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null && token.isNotEmpty) headers['Authorization'] = 'Bearer $token';
    final response = await http.get(url, headers: headers);
    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      if (decoded is List) {
        final sessions = List<Map<String, dynamic>>.from(decoded);
        if (idClasse.isNotEmpty) {
          // filtrer par idClasse en acceptant plusieurs clés possibles
          return sessions.where((s) {
            final cid = (s['idClasse'] ?? s['id_classe'] ?? s['id_classe'] ?? s['idClasse'] ?? s['classe_id'])?.toString();
            return cid == idClasse;
          }).toList();
        }
        return sessions;
      }
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getPresencesForEleve(String eleveId) async {
    final url = Uri.parse('$baseUrl/presences/eleve/$eleveId');
    final token = await _getToken();
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null && token.isNotEmpty) headers['Authorization'] = 'Bearer $token';
    final response = await http.get(url, headers: headers);
    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      if (decoded is List) {
        return List<Map<String, dynamic>>.from(decoded);
      }
    }
    return [];
  }

  // Nouvelle méthode: récupérer les inscriptions (pour retrouver id_classe d'un élève)
  Future<List<Map<String, dynamic>>> getInscriptions() async {
    final url = Uri.parse('$baseUrl/inscriptions');
    final token = await _getToken();
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null && token.isNotEmpty) headers['Authorization'] = 'Bearer $token';
    try {
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded is List) {
          return List<Map<String, dynamic>>.from(decoded);
        }
      }
    } catch (e) {
      // ignore network/json errors and return empty
    }
    return [];
  }

}
