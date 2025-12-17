// filepath: /Users/bls_int/StudioProjects/SlaterEduc/lib/services/api/eleve_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';

class EleveService {
  final String baseUrl;
  final Map<String, String> _baseHeaders;

  EleveService({this.baseUrl = apiBaseUrl, Map<String, String>? headers})
      : _baseHeaders = headers ?? {'Content-Type': 'application/json'};

  Future<String?> _getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('access_token') ?? prefs.getString('token') ?? prefs.getString('auth_token');
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, String>> _headers() async {
    final token = await _getToken();
    final h = Map<String, String>.from(_baseHeaders);
    if (token != null && token.isNotEmpty) h['Authorization'] = 'Bearer $token';
    return h;
  }

  /// Récupère la liste complète des élèves depuis l'API.
  /// On essaye quelques variantes de route selon les conventions possibles.
  Future<List<Map<String, dynamic>>> fetchEleves() async {
    final candidates = <String>[
      '$baseUrl/eleves',
      '$baseUrl/eleves/list',
      '$baseUrl/students',
      '$baseUrl/eleves/all',
    ];

    final headers = await _headers();
    for (final urlStr in candidates) {
      try {
        final url = Uri.parse(urlStr);
        final resp = await http.get(url, headers: headers).timeout(const Duration(seconds: 10));
        if (resp.statusCode == 200) {
          final body = resp.body.trim();
          if (body.isEmpty) return <Map<String, dynamic>>[];
          final decoded = json.decode(body);
          if (decoded is List) {
            return decoded
                .whereType<Map<String, dynamic>>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
          }
          if (decoded is Map<String, dynamic>) {
            final list = decoded['data'] ?? decoded['results'] ?? decoded['eleves'] ?? decoded['students'];
            if (list is List) {
              return list
                  .whereType<Map<String, dynamic>>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList();
            }
          }
        }
        if (resp.statusCode == 204) return <Map<String, dynamic>>[];
      } catch (_) {
        // essayer la prochaine route
      }
    }

    return <Map<String, dynamic>>[];
  }

  /// Récupère un élève par ID (si un endpoint direct existe), sinon retourne {}.
  Future<Map<String, dynamic>> fetchEleveById(String id) async {
    final candidates = <String>[
      '$baseUrl/eleves/$id',
      '$baseUrl/students/$id',
    ];

    final headers = await _headers();
    for (final urlStr in candidates) {
      try {
        final url = Uri.parse(urlStr);
        final resp = await http.get(url, headers: headers).timeout(const Duration(seconds: 10));
        if (resp.statusCode == 200) {
          final body = resp.body.trim();
          if (body.isEmpty) return <String, dynamic>{};
          final decoded = json.decode(body);
          if (decoded is Map<String, dynamic>) return Map<String, dynamic>.from(decoded);
          if (decoded is List && decoded.isNotEmpty && decoded.first is Map<String, dynamic>) {
            return Map<String, dynamic>.from(decoded.first as Map<String, dynamic>);
          }
        }
      } catch (_) {}
    }
    return <String, dynamic>{};
  }
}
