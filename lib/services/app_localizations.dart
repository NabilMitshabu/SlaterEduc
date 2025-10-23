import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static const _localizedValues = {
    'fr': {
      'profile': 'Profil',
      'general': 'Général',
      'settings': 'Logique',
      'notifications': 'Notifications',
      'dark_mode': 'Mode sombre',
      'language': 'Langue',
      'faq': 'FAQ',
      'help': 'Aide et Support',
      'logout': 'Déconnexion',
      // new keys
      'messages': 'Messages',
      'new_chat_with': 'Nouveau chat avec {name}',
      'result_complete': 'Résultat complet',
      'period_1': '1ère Période',
      'period_2': '2ème Période',
      'period_3': '3ème Période',
      'cours': 'Cours',
      'points_obtenus': 'Points Obtenus',
      'evaluation_type': 'Type d’évaluation',
      'evaluation_date': 'Date de l’évaluation',
      'points': 'Points',
      'download': 'Télécharger',
      'downloading': 'Téléchargement en cours...',
      'details': 'Détails',
      'description': 'Description',
      'punitions': 'Punitions',
      'punition_status': 'Statut de la punition',
      'date_label': 'Date',
      'activities': 'Activités',
      'view_activities': 'Voir les activités',
    },
    'en': {
      'profile': 'Profile',
      'general': 'General',
      'settings': 'Logic',
      'notifications': 'Notifications',
      'dark_mode': 'Dark Mode',
      'language': 'Language',
      'faq': 'FAQ',
      'help': 'Help & Support',
      'logout': 'Logout',
      // new keys
      'messages': 'Messages',
      'new_chat_with': 'New chat with {name}',
      'result_complete': 'Full Result',
      'period_1': '1st Period',
      'period_2': '2nd Period',
      'period_3': '3rd Period',
      'cours': 'Course',
      'points_obtenus': 'Points Obtained',
      'evaluation_type': 'Evaluation Type',
      'evaluation_date': 'Evaluation Date',
      'points': 'Points',
      'download': 'Download',
      'downloading': 'Download in progress...',
      'details': 'Details',
      'description': 'Description',
      'punitions': 'Punishments',
      'punition_status': 'Punishment status',
      'date_label': 'Date',
      'activities': 'Activities',
      'view_activities': 'View activities',
    },
    'sw': {
      'profile': 'Profaili',
      'general': 'Jumla',
      'settings': 'Mantiki',
      'notifications': 'Arifa',
      'dark_mode': 'Hali ya giza',
      'language': 'Lugha',
      'faq': 'Maswali',
      'help': 'Msaada na Usaidizi',
      'logout': 'Kutoka',
      // new keys
      'messages': 'Ujumbe',
      'new_chat_with': 'Soga mpya na {name}',
      'result_complete': 'Matokeo kamili',
      'period_1': 'Kipindi cha 1',
      'period_2': 'Kipindi cha 2',
      'period_3': 'Kipindi cha 3',
      'cours': 'Somo',
      'points_obtenus': 'Alama',
      'evaluation_type': 'Aina ya tathmini',
      'evaluation_date': 'Tarehe ya tathmini',
      'points': 'Alama',
      'download': 'Pakua',
      'downloading': 'Inapakua...',
      'details': 'Maelezo',
      'description': 'Maelezo',
      'punitions': 'Adhabu',
      'punition_status': 'Hali ya adhabu',
      'date_label': 'Tarehe',
      'activities': 'Shughuli',
      'view_activities': 'Tazama shughuli',
    },
  };

  // Dynamic translations loaded from an external translator (cached)
  static final Map<String, Map<String, String>> _dynamicTranslations = {};

  /// Set dynamic translations for a given language code (e.g. 'en')
  static void setDynamicTranslations(String languageCode, Map<String, String> translations) {
    _dynamicTranslations[languageCode] = translations;
  }

  /// Retrieve dynamic translations map for a language, or null.
  static Map<String, String>? getDynamicTranslations(String languageCode) {
    return _dynamicTranslations[languageCode];
  }

  /// Expose base French map used as source for automatic translation.
  static Map<String, String> baseFrench() {
    return Map<String, String>.from(_localizedValues['fr']!);
  }

  String translate(String key) {
    // Prefer dynamic translations (from AI) if available for the current locale
    final dyn = _dynamicTranslations[locale.languageCode];
    if (dyn != null && dyn.containsKey(key)) return dyn[key]!;

    return _localizedValues[locale.languageCode]?[key] ??
        _localizedValues['fr']![key] ??
        key;
  }

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  // Liste des locales supportées par l'application
  static const supportedLocales = [
    Locale('fr'),
    Locale('en'),
    Locale('sw'),
  ];
}

// Delegate pour intégrer AppLocalizations dans les delegates de Flutter
class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['fr', 'en', 'sw'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) {
    // Retourne une instance synchrone
    return SynchronousFuture<AppLocalizations>(AppLocalizations(locale));
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) => false;
}
