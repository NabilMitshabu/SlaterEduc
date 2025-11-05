import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slatereduc/services/app_localizations.dart';
import 'package:slatereduc/services/translation_service.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';

class LanguageProvider extends ChangeNotifier {
  Locale _locale;

  // Constructeur privé pour forcer l'initialisation via initialize()
  LanguageProvider._(this._locale);

  // Usine async pour charger la langue sauvegardée avant de retourner le provider
  static Future<LanguageProvider> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString('language_code') ?? 'fr';

    // Create provider instance
    final provider = LanguageProvider._(Locale(code));

    // Try to load translations in this order: bundled asset, cached SharedPreferences, remote Deepseek
    try {
      // 1) Try asset file
      final assetLoaded = await _loadAssetTranslationsIfPresent(code);
      if (assetLoaded) {
        return provider;
      }

      // 2) Try cached dynamic translations
      final loaded = await TranslationService.loadCachedTranslations(code);
      if (!loaded) {
        // 3) If no cached translations, attempt to fetch (best-effort)
        final dyn = await TranslationService.fetchTranslations(code);
        if (dyn.isNotEmpty) {
          AppLocalizations.setDynamicTranslations(code, dyn);
        }
      }
    } catch (_) {
      // ignore errors — fallback to built-in translations
    }

    return provider;
  }

  Locale get locale => _locale;

  /// Change the app language. Returns true if dynamic translations were loaded/applied.
  Future<bool> setLanguage(String languageCode) async {
    _locale = Locale(languageCode);
    // notify immediately so UI updates locale resources
    notifyListeners();

    // Persist choice
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', languageCode);

    // 1) Try to load asset translations included at build time
    try {
      final assetLoaded = await _loadAssetTranslationsIfPresent(languageCode);
      if (assetLoaded) {
        notifyListeners();
        return true;
      }
    } catch (_) {}

    // 2) First try to load cached translations
    try {
      final cachedLoaded = await TranslationService.loadCachedTranslations(languageCode);
      if (cachedLoaded) {
        // Apply and notify so the whole app rebuilds with dynamic translations
        notifyListeners();
        return true;
      }
    } catch (_) {
      // ignore
    }

    // 3) Fetch dynamic translations for the newly selected language (if possible)
    try {
      final dyn = await TranslationService.fetchTranslations(languageCode);
      if (dyn.isNotEmpty) {
        AppLocalizations.setDynamicTranslations(languageCode, dyn);
        // notify again so the whole app picks up the new translations
        notifyListeners();
        return true;
      }
    } catch (_) {
      // ignore network errors — UI will fallback to built-in translations
    }

    return false;
  }

  // Try to load translations from bundled asset assets/i18n/<lang>.json
  static Future<bool> _loadAssetTranslationsIfPresent(String lang) async {
    try {
      final path = 'assets/i18n/$lang.json';
      // rootBundle throws if asset not present, so wrap in try
      final s = await rootBundle.loadString(path);
      if (s.isEmpty) return false;
      final Map<String, dynamic> decoded = jsonDecode(s);
      final Map<String, String> mapped = decoded.map((k, v) => MapEntry(k, v.toString()));
      AppLocalizations.setDynamicTranslations(lang, mapped);
      return true;
    } catch (_) {
      return false;
    }
  }
}
