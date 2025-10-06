import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService {
  static const String baseUrl = 'http://192.168.188.115:8000';

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
        return json.decode(response.body);
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
}
