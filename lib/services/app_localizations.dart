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
      'home': 'Accueil',
      'hello': 'Bonjour,',
      'periodic_statistics': 'Statistiques Périodique',
      'progression': 'Progression',
      'avg_math': 'Moyenne Mathématique',
      'student_needs_improvement': "L'élève {name} doit améliorer sa moyenne",
      'periodic_average': 'Moyenne Périodique',
      'rank_position': 'Place au classement',
      'discipline': 'Discipline',
      'penalty_scale': 'Barème de sanction',
      'fees_balance': 'Solde de Frais',
      'first_semester': 'PREMIER DEMESTRE',
      'percentage_label': 'POURCENTAGE',
      'place_label': 'PLACE',
      'mention_label': 'MENTION',
      'history_activities': 'Historique des activités',
      'student_discipline_note': "L'élève {name} a reçu une note en Conduite",
      'today': "Aujourd'hui",
      'message_hint': 'Messages...',
      'sample_discipline_short': "Bonjour Mme Du Corbeau. Je tiens à vous informer que Neville a eu plusieurs difficultés de discipline en classe",
      'sample_discipline_long': "Bonjour Mme Du Corbeau. Je tiens à vous informer que Neville a eu plusieurs difficultés de discipline en classe cette semaine. Une rencontre est souhaitable afin d’en discuter.",
      'history_payment': 'Historique paiement',
      'paid_item': 'En règle de',
      'payment_date': 'Date de paiement',
      'amounts': 'Sommes',
      'history_punishments': 'Historique de punitions',
      'status_done': 'Effectué',
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
      'home': 'Home',
      'hello': 'Hello,',
      'periodic_statistics': 'Periodic Statistics',
      'progression': 'Progress',
      'avg_math': 'Math Average',
      'student_needs_improvement': 'Student {name} needs to improve their average',
      'periodic_average': 'Periodic Average',
      'rank_position': 'Class Rank',
      'discipline': 'Discipline',
      'penalty_scale': 'Penalty Scale',
      'fees_balance': 'Fees Balance',
      'first_semester': 'FIRST SEMESTER',
      'percentage_label': 'PERCENTAGE',
      'place_label': 'PLACE',
      'mention_label': 'MENTION',
      'history_activities': 'Activity History',
      'student_discipline_note': 'Student {name} received a Conduct grade',
      'today': 'Today',
      'message_hint': 'Messages...',
      'sample_discipline_short': 'Hello Mrs Corbeau. I inform you that Neville has had several discipline issues in class',
      'sample_discipline_long': 'Hello Mrs Corbeau. I inform you that Neville has had several discipline issues in class this week. A meeting is recommended to discuss it.',
      'history_payment': 'Payment history',
      'paid_item': 'Item',
      'payment_date': 'Payment date',
      'amounts': 'Amounts',
      'history_punishments': 'Punishment history',
      'status_done': 'Done',
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
      'home': 'Nyumbani',
      'hello': 'Habari,',
      'periodic_statistics': 'Takwimu za Kipindi',
      'progression': 'Maendeleo',
      'avg_math': 'Wastani wa Hisabati',
      'student_needs_improvement': 'Mwanafunzi {name} anahitaji kuboresha wastani wake',
      'periodic_average': 'Wastani wa Kipindi',
      'rank_position': 'Nafasi ya darasani',
      'discipline': 'Disiplin',
      'penalty_scale': 'Kigezo cha adhabu',
      'fees_balance': 'Salio la Ada',
      'first_semester': 'SEMESTA YA KWANZA',
      'percentage_label': 'ASILIMIA',
      'place_label': 'NAFASI',
      'mention_label': 'MENTION',
      'history_activities': 'Historia ya shughuli',
      'student_discipline_note': 'Mwanafunzi {name} alipokea alama katika Maadili',
      'today': 'Leo',
      'message_hint': 'Ujumbe...',
      'sample_discipline_short': 'Habari Mme Du Corbeau. Ninakuarifu kuwa Neville amekumbana na changamoto za nidhamu darasani',
      'sample_discipline_long': 'Habari Mme Du Corbeau. Ninakuarifu kuwa Neville amekumbana na changamoto za nidhamu darasani wiki hii. Mkutano unashauriwa kujadili.',
      'history_payment': 'Taarifa za malipo',
      'paid_item': 'Kiwango',
      'payment_date': 'Tarehe ya malipo',
      'amounts': 'Mizani',
      'history_punishments': 'Historia ya punitions',
      'status_done': 'Imekamilika',
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

  /// Translate and replace tokens in the form {token} using the provided [args].
  String translateWithArgs(String key, [Map<String, String>? args]) {
    String res = translate(key);
    if (args == null || args.isEmpty) return res;
    args.forEach((k, v) {
      res = res.replaceAll('{$k}', v);
    });
    return res;
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
