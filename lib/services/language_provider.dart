import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slatereduc/services/app_localizations.dart';
import 'package:slatereduc/services/translation_service.dart';

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

    // Try to fetch dynamic translations for this language (if API key configured)
    try {
      final dyn = await TranslationService.fetchTranslations(code);
      if (dyn.isNotEmpty) {
        AppLocalizations.setDynamicTranslations(code, dyn);
      }
    } catch (_) {
      // ignore errors — fallback to built-in translations
    }

    return provider;
  }

  Locale get locale => _locale;

  Future<void> setLanguage(String languageCode) async {
    _locale = Locale(languageCode);
    notifyListeners();

    // Persist choice
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', languageCode);

    // Fetch dynamic translations for the newly selected language (if possible)
    try {
      final dyn = await TranslationService.fetchTranslations(languageCode);
      if (dyn.isNotEmpty) {
        AppLocalizations.setDynamicTranslations(languageCode, dyn);
      }
    } catch (_) {
      // ignore network errors — UI will fallback to built-in translations
    }
  }
}
