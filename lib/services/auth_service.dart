import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  // Base URL de l'API
  static const String baseUrl = 'http://10.124.105.153:8000';

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

          // Certains backends renvoient l'utilisateur sous 'user'
          if (parsed.containsKey('user')) {
            final user = parsed['user'];
            // Sauvegarde l'objet user sérialisé en JSON
            await prefs.setString('user', json.encode(user));
            // Si user contient un id, on peut aussi le stocker séparément
            if (user is Map && user.containsKey('id')) {
              await prefs.setString('user_id', user['id'].toString());
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
