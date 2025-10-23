// filepath: /Users/nabilmutombo/AndroidStudioProjects/Slater-Educ--development-4/lib/services/translation_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'app_localizations.dart';

class TranslationService {
  // Utilisation exclusive de la variable d'environnement
  static const _envApiKey = String.fromEnvironment('GOOGLE_TRANSLATE_API_KEY');

  static Future<String?> _getApiKey() async {
    // Ne jamais lire/écrire la clé côté app
    if (_envApiKey.isNotEmpty) return _envApiKey;
    return null;         
  }

  static Future<Map<String, String>> fetchTranslations(String targetLang) async {
    // If target is French, return the base map (no translation needed)
    if (targetLang == 'fr') return AppLocalizations.baseFrench();

    // Return cached translations if available
    final cached = await _getCached(targetLang);
    if (cached != null && cached.isNotEmpty) return cached;

    final apiKey = await _getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      // No API key configured; return empty map -> app will fallback to built-in translations
      return {};
    }

    final source = AppLocalizations.baseFrench();
    final texts = source.values.toList();

    final uri = Uri.parse('https://translation.googleapis.com/language/translate/v2?key=$apiKey');
    final body = jsonEncode({
      'q': texts,
      'source': 'fr',
      'target': targetLang,
      'format': 'text',
    });

    try {
      final resp = await http.post(uri, headers: {'Content-Type': 'application/json'}, body: body).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body);
        final List<dynamic> translations = json['data']?['translations'] ?? [];
        final Map<String, String> result = {};
        int i = 0;
        for (var t in translations) {
          final translated = (t['translatedText'] ?? '') as String;
          // Map back to the original French key order
          final key = source.keys.elementAt(i);
          result[key] = translated;
          i += 1;
        }
        // Cache the result
        await _setCached(targetLang, result);
        return result;
      } else {
        // API error -> return empty
        return {};
      }
    } catch (e) {
      // network / timeout -> return empty
      return {};
    }
  }

  static Future<Map<String, String>?> _getCached(String lang) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('dyn_trans_$lang');
    if (raw == null) return null;
    try {
      final Map<String, dynamic> decoded = jsonDecode(raw);
      return decoded.map((k, v) => MapEntry(k, v.toString()));
    } catch (e) {
      return null;
    }
  }

  static Future<void> _setCached(String lang, Map<String, String> map) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('dyn_trans_$lang', jsonEncode(map));
  }

  static Future<String> translateText(String text, {String sourceLang = 'fr', required String targetLang}) async {
    if (targetLang == sourceLang) return text;
    final apiKey = await _getApiKey();
    if (apiKey == null || apiKey.isEmpty) return text;
    final uri = Uri.parse('https://translation.googleapis.com/language/translate/v2?key=$apiKey');
    final body = jsonEncode({
      'q': text,
      'source': sourceLang,
      'target': targetLang,
      'format': 'text',
    });
    try {
      final resp = await http.post(uri, headers: {'Content-Type': 'application/json'}, body: body).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body);
        final translations = json['data']?['translations'] ?? [];
        if (translations.isNotEmpty) {
          return (translations[0]['translatedText'] ?? text) as String;
        }
      }
      return text;
    } catch (e) {
      return text;
    }
  }
}
