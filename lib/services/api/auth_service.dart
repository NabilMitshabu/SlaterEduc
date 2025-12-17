import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';
import '../auth/user_identity_helper.dart';

class AuthService {
  // Base URL de l'API
  final String baseUrl;

  AuthService({this.baseUrl = apiBaseUrl});

  /// Retourne le token stocké (si présent) en cherchant plusieurs clés possibles.
  Future<String?> getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('access_token') ?? prefs.getString('token') ?? prefs.getString('auth_token');
    } catch (_) {
      return null;
    }
  }

  /// Vérifie si un token est présent en local et affiche des logs de debug.
  Future<bool> isAuthenticated() async {
    print('DEBUG: AuthService.isAuthenticated - Checking authentication...');
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool has = prefs.containsKey('access_token') || prefs.containsKey('token') || prefs.containsKey('auth_token');
      print('DEBUG: AuthService.isAuthenticated - Token exists: $has');
      if (!has) print('DEBUG: AuthService.isAuthenticated - No token found');
      return has;
    } catch (e) {
      print('DEBUG: AuthService.isAuthenticated - Error reading prefs: $e');
      return false;
    }
  }

  /// Debug helper: print les clés d'auth stockées (ne pas utiliser en production).
  Future<void> debugPrintStoredAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final authKeys = keys.where((k) => k.contains('token') || k.contains('auth') || k.contains('user')).toList();
      print('DEBUG: AuthService.debugPrintStoredAuth - keys: ${authKeys.join(', ')}');
      for (final k in authKeys) {
        try {
          final v = prefs.getString(k) ?? '<binary or non-string>';
          final safe = (k.toLowerCase().contains('token')) ? '[REDACTED]' : v;
          print('DEBUG: AuthService.debugPrintStoredAuth - $k = $safe');
        } catch (_) {}
      }
    } catch (e) {
      print('DEBUG: AuthService.debugPrintStoredAuth - failed: $e');
    }
  }

  /// Try to extract a token string from a parsed login response (handles several shapes).
  String? _extractTokenFromParsed(Map<String, dynamic> parsed) {
    try {
      // common top-level keys
      for (final k in ['access_token', 'token', 'auth_token', 'authorization']) {
        if (parsed.containsKey(k) && parsed[k] is String && (parsed[k] as String).isNotEmpty) return parsed[k] as String;
      }
      // sometimes the token is under data or meta
      if (parsed.containsKey('data') && parsed['data'] is Map) {
        final m = Map<String, dynamic>.from(parsed['data'] as Map);
        for (final k in ['access_token', 'token', 'auth_token', 'authorization']) {
          if (m.containsKey(k) && m[k] is String && (m[k] as String).isNotEmpty) return m[k] as String;
        }
      }
      if (parsed.containsKey('meta') && parsed['meta'] is Map) {
        final m = Map<String, dynamic>.from(parsed['meta'] as Map);
        for (final k in ['access_token', 'token', 'auth_token', 'authorization']) {
          if (m.containsKey(k) && m[k] is String && (m[k] as String).isNotEmpty) return m[k] as String;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final parsed = json.decode(response.body) as Map<String, dynamic>;

        // Sauvegarde des tokens et de l'utilisateur dans SharedPreferences
        try {
          final prefs = await SharedPreferences.getInstance();
          if (parsed.containsKey('access_token') && parsed['access_token'] is String) {
            await prefs.setString('access_token', parsed['access_token']);
          }
          if (parsed.containsKey('refresh_token') && parsed['refresh_token'] is String) {
            await prefs.setString('refresh_token', parsed['refresh_token']);
          }
          if (parsed.containsKey('token_type') && parsed['token_type'] is String) {
            await prefs.setString('token_type', parsed['token_type']);
          }

          // If token wasn't present under common names above, try to find it in other nested shapes
          final extracted = _extractTokenFromParsed(parsed);
          if ((await getToken()) == null && extracted != null && extracted.isNotEmpty) {
            await prefs.setString('access_token', extracted);
            print('DEBUG: AuthService.login - extracted and saved token from response');
          }

          // Certains backends renvoient l'utilisateur sous 'user'
          if (parsed.containsKey('user')) {
            final user = parsed['user'];
            await prefs.setString('user', json.encode(user));
            String? resolvedId;
            if (user is Map) {
              if (user['id'] != null) resolvedId = user['id'].toString();
              else if (user['id_user'] != null) resolvedId = user['id_user'].toString();
              else if (user['user_id'] != null) resolvedId = user['user_id'].toString();
            }
            if (resolvedId != null && resolvedId.isNotEmpty) {
              await prefs.setString('user_id', resolvedId);
              await prefs.setString('id_user', resolvedId);
              UserIdentityHelper.instance.cacheUserId(resolvedId);
            }
          }
        } catch (e) {
          // Ne pas empêcher le login si la sauvegarde échoue; on log l'erreur
          print('Impossible de sauvegarder les tokens en local: $e');
        }

        return parsed;
      } else {
        print('Erreur de connexion: statusCode=${response.statusCode}, body=${response.body}');
        throw Exception('Échec de la connexion: ${response.body}');
      }
    } catch (e) {
      print('Exception lors de la connexion: $e');
      throw Exception('Erreur de connexion: $e');
    }
  }

  Future<Map<String, dynamic>> register(String username, String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username,
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        throw Exception('Échec de l\'inscription: ${response.body}');
      }
    } catch (e) {
      throw Exception('Erreur d\'inscription: $e');
    }
  }

  // Envoie la demande de réinitialisation en utilisant le numéro de téléphone
  Future<void> forgotPassword(String phone) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'phone': phone}),
      );
      if (response.statusCode == 200) {
        // Succès, l'API a envoyé l'email
        return;
      } else {
        throw Exception('Échec de la demande: ${response.body}');
      }
    } catch (e) {
      throw Exception('Erreur lors de la demande: $e');
    }
  }
}
