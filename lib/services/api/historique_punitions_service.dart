import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class Punition {
  final String id;
  final String description;
  final String motif;
  final String idEleve;
  final int status;
  final String date;

  Punition({
    required this.id,
    required this.description,
    required this.motif,
    required this.idEleve,
    required this.status,
    required this.date,
  });

  factory Punition.fromJson(Map<String, dynamic> json) {
    return Punition(
      id: json['id'] ?? '',
      description: json['description'] ?? '',
      motif: json['motif'] ?? '',
      idEleve: json['idEleve'] ?? '',
      status: json['status'] ?? 0,
      date: json['date'] ?? '',
    );
  }
}

class HistoriquePunitionsService {
  final String baseUrl;
  HistoriquePunitionsService({this.baseUrl = apiBaseUrl});

  Future<List<Punition>> fetchPunitions(String studentId) async {
    final response = await http.get(Uri.parse('$baseUrl/punitions?idEleve=$studentId'));
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      // Filtrer localement si l'API ne filtre pas
      return data.map((e) => Punition.fromJson(e)).where((p) => p.idEleve == studentId).toList();
    } else {
      throw Exception('Erreur lors du chargement des punitions');
    }
  }
}
