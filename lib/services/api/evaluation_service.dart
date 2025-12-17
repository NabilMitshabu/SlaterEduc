import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class EvaluationService {
  final String baseUrl;
  final Map<String, String> headers;

  EvaluationService({this.baseUrl = apiBaseUrl, Map<String, String>? headers})
      : headers = headers ?? {'Content-Type': 'application/json'};

  Future<List<dynamic>> fetchPeriodes() async {
    final candidates = [
      '$baseUrl/periodes',
      '$baseUrl/periods',
    ];
    return _tryCandidatesList(candidates, 'periodes');
  }

  Future<List<dynamic>> fetchEvaluationTypes() async {
    final candidates = [
      '$baseUrl/evaluations/type-evaluations',
      '$baseUrl/evaluations/type_evaluations',
      '$baseUrl/evaluations/types',
    ];
    return _tryCandidatesList(candidates, 'evaluation types');
  }

  Future<List<dynamic>> fetchEvaluations() async {
    final candidates = [
      '$baseUrl/evaluations',
      '$baseUrl/evaluations/list',
    ];
    return _tryCandidatesList(candidates, 'evaluations');
  }

  Future<List<dynamic>> fetchEvaluationEleves() async {
    final candidates = [
      '$baseUrl/evaluations/eleves',
      '$baseUrl/evaluations/eleves/list',
      '$baseUrl/evaluations/eleves',
    ];
    return _tryCandidatesList(candidates, 'evaluation eleves');
  }

  Future<List<dynamic>> fetchCourses() async {
    final candidates = [
      '$baseUrl/cours',
      '$baseUrl/courses',
      '$baseUrl/cours/list',
    ];
    return _tryCandidatesList(candidates, 'courses');
  }

  /// Fetch mapping between cours-prof and periods (endpoint name may vary: cours_prof_periods)
  Future<List<dynamic>> fetchCoursProfPeriods() async {
    final candidates = [
      '$baseUrl/cours/prof/period',
    ];
    return _tryCandidatesList(candidates, 'cours_prof_periods');
  }

  /// Fetch cours_profs entries (associations cours <-> personnels <-> classes)
  Future<List<dynamic>> fetchCoursProfs() async {
    final candidates = [
      '$baseUrl/cours/prof',
    ];
    return _tryCandidatesList(candidates, 'cours_profs');
  }

  Future<List<dynamic>> _tryCandidatesList(List<String> candidates, String label) async {
    final Map<String, String> outcomes = {};
    for (final urlStr in candidates) {
      try {
        final url = Uri.parse(urlStr);
        final resp = await http.get(url, headers: headers).timeout(Duration(seconds: 10));
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
    // if none succeeded, return empty list rather than throwing so UI can degrade gracefully
    return <dynamic>[];
  }
}
