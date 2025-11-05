// Tool to translate all strings from AppLocalizations.baseFrench() using Deepseek
// Usage (from project root):
// DEESEEK_API_KEY=your_key dart run tool/translate_all.dart --langs=en,sw

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

// We cannot import Flutter-dependent files in a pure Dart script. Instead
// we read lib/services/app_localizations.dart and extract the 'fr' map.

Future<Map<String, String>> loadBaseFrench() async {
  final path = 'lib/services/app_localizations.dart';
  final f = File(path);
  if (!await f.exists()) {
    stderr.writeln('Could not find $path');
    exit(2);
  }
  final content = await f.readAsString();

  // find the start of the _localizedValues map and then the 'fr' entry
  final localizedIdx = content.indexOf('static const _localizedValues');
  if (localizedIdx == -1) {
    stderr.writeln('Could not find _localizedValues in $path');
    exit(2);
  }
  final frKeyIdx = content.indexOf("'fr'", localizedIdx);
  if (frKeyIdx == -1) {
    stderr.writeln('Could not find fr map in $path');
    exit(2);
  }

  // find opening brace for the 'fr' map
  final braceStart = content.indexOf('{', frKeyIdx);
  if (braceStart == -1) {
    stderr.writeln('Malformed fr map in $path');
    exit(2);
  }

  // find matching closing brace
  int i = braceStart;
  int depth = 0;
  for (; i < content.length; i++) {
    final ch = content.codeUnitAt(i);
    if (ch == '{'.codeUnitAt(0)) depth++;
    if (ch == '}'.codeUnitAt(0)) {
      depth--;
      if (depth == 0) break;
    }
  }
  if (depth != 0) {
    stderr.writeln('Could not find end of fr map in $path');
    exit(2);
  }

  final dartMapText = content.substring(braceStart, i + 1);
  final jsonText = dartMapToJson(dartMapText);
  try {
    final decoded = jsonDecode(jsonText) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
  } catch (e) {
    stderr.writeln('Failed to decode fr map to JSON: $e');
    stderr.writeln('Candidate JSON:\n$jsonText');
    exit(2);
  }
}

String dartMapToJson(String dartMap) {
  // Convert Dart single-quoted strings to JSON double-quoted strings.
  // This regex finds single-quoted strings, handling escaped quotes.
  final reg = RegExp(r"'([^'\\]*(?:\\.[^'\\]*)*)'");
  String replaced = dartMap.replaceAllMapped(reg, (m) {
    final inner = m[1] ?? '';
    // Unescape any escaped single quotes and backslashes for JSON encoding
    final unescaped = inner.replaceAll("\\'", "'").replaceAll('\\\\', '\\');
    final jsonEscaped = jsonEncode(unescaped); // returns a double-quoted JSON string
    return jsonEscaped;
  });

  // Remove trailing commas before closing braces (JSON doesn't allow them)
  replaced = replaced.replaceAll(RegExp(r',\s*}'), '}');
  replaced = replaced.replaceAll(RegExp(r',\s*\]'), ']');
  return replaced;
}

const int maxCharsPerBatch = 3000;

Future<void> main(List<String> args) async {
  final envKey = Platform.environment['DEESEEK_API_KEY'];
  if (envKey == null || envKey.isEmpty) {
    stderr.writeln('DEESEEK_API_KEY not set. Export it in the environment.');
    exit(2);
  }

  // parse args --langs=..
  final langsArg = args.firstWhere((a) => a.startsWith('--langs='), orElse: () => '--langs=en');
  final langs = langsArg.substring('--langs='.length).split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

  print('Translating to languages: ${langs.join(', ')}');

  final source = await loadBaseFrench();
  final keys = source.keys.toList();

  for (final lang in langs) {
    print('\n--- Translating to $lang ---');
    final result = <String, String>{};

    // build batches of keys
    final batches = <List<String>>[];
    var current = <String>[];
    var currentLen = 0;
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

    print('Total keys: ${keys.length}, batches: ${batches.length}');

    for (var i = 0; i < batches.length; i++) {
      final batchKeys = batches[i];
      final promptBuf = StringBuffer();
      final Map<String, String> tokenMap = {};
      promptBuf.writeln('Translate the following French strings to $lang and return ONLY a JSON object with the same keys and their translated values.');
      promptBuf.writeln('Preserve placeholders like {name} exactly.');
      promptBuf.writeln('Do not add any extra commentary or explanation.');
      promptBuf.writeln();
      promptBuf.writeln('{');
      for (var j = 0; j < batchKeys.length; j++) {
        final k = batchKeys[j];
        final v = source[k]?.replaceAll('\n', ' ') ?? '';
        final encoded = _encodePlaceholders(v, tokenMap);
        promptBuf.writeln('  "${k}": "${_escapeForPrompt(encoded)}"${j == batchKeys.length - 1 ? '' : ','}');
      }
      promptBuf.writeln('}');

      final prompt = promptBuf.toString();
      final uri = Uri.parse('https://api.deepseek.com/v1/chat/completions');
      final body = jsonEncode({
        'model': 'deepseek-chat',
        'messages': [
          {'role': 'system', 'content': 'You are a reliable translator. Return ONLY the JSON object requested, and do not add any commentary.'},
          {'role': 'user', 'content': prompt}
        ],
        'max_tokens': 2000,
      });

      try {
        print('Batch ${i + 1}/${batches.length}: POST $uri (keys=${batchKeys.length})');
        final resp = await http.post(uri, headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $envKey',
        }, body: body).timeout(const Duration(seconds: 30));

        if (resp.statusCode != 200) {
          stderr.writeln('Batch ${i + 1} failed HTTP ${resp.statusCode}: ${resp.body}');
          continue;
        }

        final content = _extractTextFromDeepseekResponse(resp.body);
        if (content == null || content.isEmpty) {
          stderr.writeln('Batch ${i + 1} empty content');
          continue;
        }

        final parsed = _extractJsonObject(content);
        if (parsed != null && parsed.isNotEmpty) {
          for (final k in batchKeys) {
            if (parsed.containsKey(k)) {
              final rawTranslated = (parsed[k] ?? '').toString();
              result[k] = _restorePlaceholders(rawTranslated, tokenMap);
            }
          }
          print('Batch ${i + 1} parsed JSON, added ${parsed.keys.length} keys');
          continue;
        }

        // fallback line-by-line
        final lines = content
            .split(RegExp(r"\r?\n"))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        if (lines.isNotEmpty) {
          for (var j = 0; j < batchKeys.length && j < lines.length; j++) {
            result[batchKeys[j]] = _restorePlaceholders(lines[j], tokenMap);
          }
          print('Batch ${i + 1} used line-by-line fallback');
          continue;
        }

        stderr.writeln('Batch ${i + 1} could not parse response. Raw:\n$content');
      } catch (e) {
        stderr.writeln('Exception during batch ${i + 1}: $e');
        continue;
      }
    }

    // merge with base French to ensure all keys exist (fallback to french if missing)
    final merged = <String, String>{};
    for (final k in keys) {
      merged[k] = result[k] ?? source[k] ?? k;
    }

    // write to assets/i18n/<lang>.json
    final outDir = Directory('assets/i18n');
    if (!await outDir.exists()) await outDir.create(recursive: true);
    final outFile = File('assets/i18n/$lang.json');
    await outFile.writeAsString(JsonEncoder.withIndent('  ').convert(merged));
    print('Wrote ${merged.length} translations to ${outFile.path}');
  }

  print('\nDone.');
}

String _escapeForPrompt(String s) {
  return s.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
}

String _encodePlaceholders(String s, Map<String, String> tokenMap) {
  final reg = RegExp(r'\{[^}]+\}');
  return s.replaceAllMapped(reg, (m) {
    final ph = m[0]!;
    final token = '<<PH${tokenMap.length}>>';
    tokenMap[token] = ph;
    return token;
  });
}

String _restorePlaceholders(String s, Map<String, String> tokenMap) {
  if (tokenMap.isEmpty) return s;
  var out = s;
  tokenMap.forEach((token, ph) {
    out = out.replaceAll(token, ph);
  });
  return out;
}

String? _extractTextFromDeepseekResponse(String body) {
  try {
    final j = jsonDecode(body);
    if (j is Map) {
      if (j['choices'] is List && j['choices'].isNotEmpty) {
        final c0 = j['choices'][0];
        if (c0 is Map && c0['message'] is Map && c0['message']['content'] != null) return c0['message']['content'].toString();
        if (c0 is Map && c0['text'] != null) return c0['text'].toString();
      }
      if (j['output'] is String) return j['output'] as String;
    }
  } catch (e) {
    // ignore
  }
  return body;
}

Map<String, dynamic>? _extractJsonObject(String text) {
  final start = text.indexOf('{');
  final end = text.lastIndexOf('}');
  if (start == -1 || end == -1 || end <= start) return null;
  final candidate = text.substring(start, end + 1);
  try {
    final parsed = jsonDecode(candidate);
    if (parsed is Map<String, dynamic>) return parsed;
  } catch (e) {
    stderr.writeln('Failed to parse candidate JSON: $e');
    stderr.writeln('Candidate was:\n$candidate');
  }
  return null;
}
