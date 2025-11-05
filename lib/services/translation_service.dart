// filepath: /Users/nabilmutombo/AndroidStudioProjects/Slater-Educ--development-4/lib/services/translation_service.dart
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'app_localizations.dart';

class TranslationService {
  // Utilisation exclusive de la variable d'environnement (passer avec --dart-define=DEESEEK_API_KEY=...)
  // Note: use DEEPSEEK_API_KEY (with P) to match the Python script and environment variable usage
  static const _envApiKey = String.fromEnvironment('DEEPSEEK_API_KEY');

  static Future<String?> _getApiKey() async {
    // Only use compile-time environment variable. Do NOT store the key inside the app.
    if (_envApiKey.isNotEmpty) return _envApiKey;
    return null;
  }

  /// Récupère les traductions pour [targetLang].
  ///
  /// Strategy:
  /// - Si targetLang == 'fr' on retourne les chaînes de base.
  /// - Si une cache existe, on la retourne.
  /// - Sinon on interroge l'API Deepseek en demandant une réponse JSON contenant
  ///   un objet de la forme { "key": "translated text", ... }.
  static Future<Map<String, String>> fetchTranslations(String targetLang, {String model = 'deepseek-chat'}) async {
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
    final keys = source.keys.toList();

    // --- Batch/chunking logic ---
    const int maxCharsPerBatch = 3000; // rough heuristic to avoid extremely large prompts
    final List<List<String>> batches = [];
    List<String> current = [];
    int currentLen = 0;

    for (final k in keys) {
      final v = source[k]?.replaceAll('\n', ' ') ?? '';
      final est = k.length + v.length;
      if (current.isNotEmpty && (currentLen + est > maxCharsPerBatch)) {
        batches.add(List<String>.from(current));
        current = [];
        currentLen = 0;
      }
      current.add(k);
      currentLen += est;
    }
    if (current.isNotEmpty) batches.add(List<String>.from(current));

    final Map<String, String> finalResult = {};

    // Process each batch sequentially
    for (final batchKeys in batches) {
      final buf = StringBuffer();
      // placeholder token map for this batch: token -> originalPlaceholder
      final Map<String, String> tokenMap = {};
      buf.writeln('Translate the following French strings to $targetLang and return ONLY a JSON object with the same keys and their translated values.');
      buf.writeln('Preserve placeholders like {name} exactly.');
      buf.writeln('Do not add any extra commentary or explanation.');
      buf.writeln();
      buf.writeln('{');
      for (var i = 0; i < batchKeys.length; i++) {
        final k = batchKeys[i];
        final raw = source[k]?.replaceAll('\n', ' ') ?? '';
        final encoded = _encodePlaceholders(raw, tokenMap);
        buf.writeln('  "${k}": "${_escapeForPrompt(encoded)}"${i == batchKeys.length - 1 ? '' : ','}');
      }
      buf.writeln('}');

      final promptBatch = buf.toString();

      final uri = Uri.parse('https://api.deepseek.com/v1/chat/completions');
      final body = jsonEncode({
        'model': model,
        'messages': [
          {'role': 'system', 'content': 'You are a reliable translator. Return ONLY the JSON object requested, and do not add any commentary.'},
          {'role': 'user', 'content': promptBatch}
        ],
        'max_tokens': 2000,
      });

      try {
        if (kDebugMode) {
          final preview = (body.length > 800) ? '${body.substring(0, min(800, body.length))}... (truncated)' : body;
          print('[TranslationService] POST $uri (batch size=${batchKeys.length})');
          print('[TranslationService] Request body preview:\n$preview');
        }

        final resp = await http.post(uri, headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        }, body: body).timeout(const Duration(seconds: 20));

        if (resp.statusCode != 200) {
          if (kDebugMode) {
            print('[TranslationService] Batch request failed HTTP ${resp.statusCode}');
            print('[TranslationService] Raw HTTP body:\n${resp.body}');
          }
          // continue with next batch
          continue;
        }

        final content = _extractTextFromDeepseekResponse(resp.body);
        if (content == null || content.isEmpty) {
          if (kDebugMode) print('[TranslationService] Empty response content for batch');
          continue;
        }

        // First try JSON extraction
        final Map<String, dynamic>? parsed = _extractJsonObject(content);
        if (parsed != null && parsed.isNotEmpty) {
          for (final k in batchKeys) {
            if (parsed.containsKey(k)) {
              // restore placeholders in the translated value
              final rawTranslated = (parsed[k] ?? '').toString();
              final restored = _restorePlaceholders(rawTranslated, tokenMap);
              finalResult[k] = restored;
            }
          }
          // continue to next batch
          continue;
        }

        // Fallback line-by-line mapping
        final lines = content
            .split(RegExp(r"\r?\n"))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        if (lines.isNotEmpty) {
          for (var i = 0; i < batchKeys.length && i < lines.length; i++) {
            finalResult[batchKeys[i]] = _restorePlaceholders(lines[i], tokenMap);
          }
          continue;
        }

        // If we reach here, nothing parsed for this batch
        if (kDebugMode) {
          print('[TranslationService] Could not parse translations for batch with keys: ${batchKeys.join(', ')}');
          print('[TranslationService] Raw response:\n$content');
        }
      } catch (e) {
        if (kDebugMode) print('[TranslationService] Exception during batch request: $e');
        // continue with next batch
        continue;
      }
    }

    if (finalResult.isNotEmpty) {
      await _setCached(targetLang, finalResult);
      return finalResult;
    }

    return {};
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

  /// Charge les traductions mises en cache pour [lang] et les applique à AppLocalizations.
  /// Retourne true si des traductions ont été appliquées.
  static Future<bool> loadCachedTranslations(String lang) async {
    final cached = await _getCached(lang);
    if (cached != null && cached.isNotEmpty) {
      AppLocalizations.setDynamicTranslations(lang, cached);
      return true;
    }
    return false;
  }

  static Future<void> _setCached(String lang, Map<String, String> map) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('dyn_trans_$lang', jsonEncode(map));
  }

  /// Traduction d'un seul texte via Deepseek.
  static Future<String> translateText(String text, {String sourceLang = 'fr', required String targetLang, String model = 'deepseek-chat'}) async {
    if (targetLang == sourceLang) return text;
    final apiKey = await _getApiKey();
    if (apiKey == null || apiKey.isEmpty) return text;

    final prompt = 'Translate the following $sourceLang text to $targetLang. Return only the translated text.\n\n$text';

    final uri = Uri.parse('https://api.deepseek.com/v1/chat/completions');
    final body = jsonEncode({
      'model': model,
      'messages': [
        {'role': 'system', 'content': 'You are a reliable translator. Return ONLY the translated text.'},
        {'role': 'user', 'content': prompt}
      ],
      'max_tokens': 1000,
    });

    try {
      final resp = await http.post(uri, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      }, body: body).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final content = _extractTextFromDeepseekResponse(resp.body);
        if (content != null && content.isNotEmpty) {
          // If content contains a JSON string, try to extract the plain translated text
          final jsonObj = _extractJsonObject(content);
          if (jsonObj != null && jsonObj.isNotEmpty) {
            // If the model returned an object with a single value, return it
            if (jsonObj.values.isNotEmpty) return jsonObj.values.first.toString();
          }
          // Otherwise return the content as-is (trimmed)
          return content.trim();
        }
      }
      return text;
    } catch (e) {
      return text;
    }
  }

  // --- Helpers ---

  static String _escapeForPrompt(String s) {
    // Escape double quotes and backslashes to avoid breaking the prompt JSON
    return s.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
  }

  // Encode placeholders like {name} into tokens (per batch) and record mapping into tokenMap.
  static String _encodePlaceholders(String s, Map<String, String> tokenMap) {
    // Matches {anything} non-greedy
    final reg = RegExp(r'\{[^}]+\}');
    return s.replaceAllMapped(reg, (m) {
      final ph = m[0]!;
      final token = '<<PH${tokenMap.length}>>';
      tokenMap[token] = ph;
      return token;
    });
  }

  // Restore tokens back to their original placeholders using tokenMap
  static String _restorePlaceholders(String s, Map<String, String> tokenMap) {
    if (tokenMap.isEmpty) return s;
    var out = s;
    tokenMap.forEach((token, ph) {
      out = out.replaceAll(token, ph);
    });
    return out;
  }

  static String? _extractTextFromDeepseekResponse(String body) {
    try {
      final dynamic j = jsonDecode(body);
      // Common shapes: { "output": "..." } or { "output": [{"content":"..."}]} or {"choices":[{"message":{"content":"..."}}]}
      if (j is Map) {
        if (j['output'] is String) return j['output'] as String;
        if (j['output'] is List && j['output'].isNotEmpty) {
          final first = j['output'][0];
          if (first is Map && first['content'] != null) return first['content'].toString();
          if (first is Map && first['text'] != null) return first['text'].toString();
          if (first is String) return first;
        }
        if (j['choices'] is List && j['choices'].isNotEmpty) {
          final c0 = j['choices'][0];
          if (c0 is Map && c0['message'] is Map && c0['message']['content'] != null) return c0['message']['content'].toString();
          if (c0 is Map && c0['text'] != null) return c0['text'].toString();
        }
        if (j['data'] is Map && j['data']['output'] is String) return j['data']['output'];
      }
    } catch (e) {
      // body might be plain text or malformed JSON; in debug mode print it for diagnosis
      if (kDebugMode) {
        print('[TranslationService] _extractTextFromDeepseekResponse: failed to decode JSON: $e');
        print('[TranslationService] Raw response body:\n$body');
      }
    }
    // If body isn't JSON or we couldn't find fields, return the raw body as fallback
    return body;
  }

  static Map<String, dynamic>? _extractJsonObject(String text) {
    // Find the first '{' and the matching '}' (simple approach: last '}' in the string)
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start == -1 || end == -1 || end <= start) return null;
    final candidate = text.substring(start, end + 1);
    try {
      final parsed = jsonDecode(candidate);
      if (parsed is Map<String, dynamic>) return parsed;
    } catch (e) {
      if (kDebugMode) {
        print('[TranslationService] _extractJsonObject: failed to parse candidate JSON. Candidate:\n$candidate');
        print('[TranslationService] Error: $e');
      }
      // parsing failed
    }
    return null;
  }
}
