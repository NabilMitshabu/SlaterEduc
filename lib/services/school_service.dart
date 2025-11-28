import 'dart:convert';
import 'package:http/http.dart' as http;

class SchoolService {
  final String baseUrl;
  final Map<String, String> headers;

  SchoolService({this.baseUrl = 'http://192.168.1.70:8000', Map<String, String>? headers})
      : headers = headers ?? {'Content-Type': 'application/json'};

  /// Fetch list of cours-profs. Try multiple candidate paths to be tolerant to API route differences.
  Future<List<dynamic>> fetchCoursProfs() async {
    final candidates = [
      '$baseUrl/cours/prof',
      '$baseUrl/cours-profs',
      '$baseUrl/coursprofs',
      '$baseUrl/cours/profs',
      '$baseUrl/cours_prof',
      '$baseUrl/cours/professeurs',
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
}
