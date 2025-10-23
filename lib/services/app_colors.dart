import 'package:flutter/material.dart';

class AppColors {
  // Palette principale
  static const Color primaryBase = Color(0xFF1B54F5); // bleu principal demandé
  static const Color primaryVariant = Color(0xFF153FBF); // variante plus foncée
  static const Color secondaryBase = Color(0xFF5C8DF6); // accent / secondaire
  static const Color secondaryVariant = Color(0xFF2E6FE8);
  static const Color accent = Color(0xFF5C8DF6); // variante claire (historique)

  // Fond / surface
  static const Color backgroundLight = Color(0xFFF5F6FA);
  static const Color backgroundDark = Color(0xFF0F1115);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF1B1B1B);

  // Texte
  static const Color textLight = Color(0xFF222222);
  static const Color textDark = Color(0xFFF5F6FA);

  // Feedback
  static const Color error = Color(0xFFB00020);
  static const Color success = Color(0xFF28A745);

  // Accesseurs selon thème
  static Color primary(BuildContext context) => primaryBase;
  static Color primaryVariantColor(BuildContext context) => primaryVariant;
  static Color secondaryColor(BuildContext context) => secondaryBase;
  static Color secondaryVariantColor(BuildContext context) => secondaryVariant;
  static Color accentColor(BuildContext context) => accent;

  static Color background(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? backgroundDark : backgroundLight;
  static Color surface(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? surfaceDark : surfaceLight;
  static Color scaffold(BuildContext context) => background(context);

  static Color text(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? textDark : textLight;

  static Color onPrimary(BuildContext context) => Colors.white;
  static Color onSecondary(BuildContext context) => Colors.white;
  static Color onBackground(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? textDark : textLight;
  static Color onSurface(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? textDark : textLight;

  static Color errorColor(BuildContext context) => error;
  static Color successColor(BuildContext context) => success;

  // Utility to return a color with opacity without using Color.withOpacity (deprecated)
  static Color alpha(Color color, double opacity) {
    return Color.fromRGBO(color.red, color.green, color.blue, opacity);
  }

  // Couleurs spécifiques pour les animations d'icônes sur la page de login
  static const Color iconSchool = Color(0xFF4CAF50); // vert vif
  static const Color iconBook = Color(0xFFFFA726); // orange clair
  static const Color iconChat = Color(0xFF42A5F5); // bleu clair
  static const Color iconProfile = Color(0xFFAB47BC); // violet doux

  // Retourne la couleur d'icône correspondante
  static Color scenarioColor(int index) {
    switch (index) {
      case 0:
        return iconSchool;
      case 1:
        return iconBook;
      case 2:
        return iconChat;
      case 3:
        return iconProfile;
      default:
        return primaryBase;
    }
  }

}
