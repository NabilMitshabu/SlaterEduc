import 'dart:convert';
import 'package:http/http.dart' as http;
import 'user_model.dart';

class UserService {
  final String baseUrl;

  UserService({this.baseUrl = 'http://192.168.188.23:8000'});

  Future<List<User>> getAllUsers() async {
    final response = await http.get(Uri.parse('$baseUrl/users'));
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => User.fromJson(json)).toList();
    } else {
      throw Exception('Erreur lors de la récupération des utilisateurs');
    }
  }

  Future<Map<String, dynamic>> registerUser({
    required String username,
    required String email,
    required String password,
  }) async {
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
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Erreur lors de l\'inscription: ${response.body}');
    }
  }
}
