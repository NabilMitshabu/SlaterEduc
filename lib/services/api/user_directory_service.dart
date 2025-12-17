import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';

class UserDirectoryService {
  final String baseUrl;
  final Map<String, String> baseHeaders;

  UserDirectoryService({this.baseUrl = apiBaseUrl, Map<String, String>? headers})
      : baseHeaders = headers ?? {'Content-Type': 'application/json'};

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
    final h = Map<String, String>.from(baseHeaders);
    if (token != null && token.isNotEmpty) h['Authorization'] = 'Bearer $token';
    return h;
  }

  Future<Map<String, String>> _loadCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('user_name_cache');
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = json.decode(raw);
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
      }
    } catch (_) {}
    return {};
  }

  Future<void> _saveCache(Map<String, String> cache) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name_cache', json.encode(cache));
  }

  Future<void> _putInCache(String id, String name) async {
    final cache = await _loadCache();
    cache[id] = name;
    await _saveCache(cache);
  }

  String _composeName(Map<String, dynamic> m) {
    final first = (m['first_name'] ?? m['firstname'] ?? m['firstName'])?.toString();
    final last = (m['last_name'] ?? m['lastname'] ?? m['lastName'])?.toString();
    final username = m['username']?.toString();
    if (first != null && last != null && first.isNotEmpty && last.isNotEmpty) return '$first $last';
    if (first != null && first.isNotEmpty) return first;
    if (last != null && last.isNotEmpty) return last;
    final name = (m['name'] ?? m['full_name'] ?? m['fullName'])?.toString();
    if (name != null && name.isNotEmpty) return name;
    if (username != null && username.isNotEmpty) return username;
    return '';
  }

  Future<String?> _tryGetSingle(String url) async {
    try {
      final h = await _headers();
      final resp = await http.get(Uri.parse(url), headers: h).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final body = resp.body.trim();
        if (body.isEmpty) return null;
        final decoded = json.decode(body);
        if (decoded is Map<String, dynamic>) {
          final name = _composeName(decoded);
          return name.isNotEmpty ? name : null;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<String?> _tryGetFromList(String url, String id) async {
    try {
      final h = await _headers();
      final resp = await http.get(Uri.parse(url), headers: h).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final body = resp.body.trim();
        if (body.isEmpty) return null;
        final decoded = json.decode(body);
        final List<dynamic> list = decoded is List
            ? decoded
            : (decoded is Map && decoded['data'] is List ? decoded['data'] : (decoded is Map && decoded['results'] is List ? decoded['results'] : []));
        for (final item in list) {
          if (item is Map) {
            final map = Map<String, dynamic>.from(item);
            final idCandidate = (map['id'] ?? map['id_user'] ?? map['user_id'])?.toString();
            if (idCandidate == id) {
              final name = _composeName(map);
              if (name.isNotEmpty) return name;
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// Resolve a user's display name (first+last) by their id or user_id.
  /// Caches results in SharedPreferences to avoid repeated calls.
  Future<String> resolveUserName(String userId) async {
    if (userId.isEmpty) return '';

    final cache = await _loadCache();
    if (cache.containsKey(userId)) return cache[userId]!;

    // Try specific endpoints first
    final singleCandidates = <String>[
      '$baseUrl/users/$userId',
      '$baseUrl/parents/$userId',
      '$baseUrl/eleves/$userId',
      '$baseUrl/personnels/$userId',
    ];
    for (final url in singleCandidates) {
      final name = await _tryGetSingle(url);
      if (name != null && name.isNotEmpty) {
        await _putInCache(userId, name);
        return name;
      }
    }

    // Fallback to list endpoints
    final listCandidates = <String>[
      '$baseUrl/users',
      '$baseUrl/parents',
      '$baseUrl/eleves',
      '$baseUrl/personnels',
    ];
    for (final url in listCandidates) {
      final name = await _tryGetFromList(url, userId);
      if (name != null && name.isNotEmpty) {
        await _putInCache(userId, name);
        return name;
      }
    }

    return '';
  }
}

