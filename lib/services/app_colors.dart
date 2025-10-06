import 'package:flutter/material.dart';

class AppColors {
  static const Color primaryBase = Color(0xFF1B54F5); // bleu principal
  static const Color secondary = Color(0xFF1746C6); // variante plus foncée
  static const Color accent = Color(0xFF5C8DF6); // variante plus claire
  static const Color backgroundLight = Color(0xFFF5F6FA);
  static const Color backgroundDark = Color(0xFF121212);
  static const Color textLight = Color(0xFF222222);
  static const Color textDark = Color(0xFFF5F6FA);
  static const Color error = Colors.red;
  static const Color success = Colors.green;

  static Color primary(BuildContext context) => primaryBase;
  static Color accentColor(BuildContext context) => accent;
  static Color secondaryColor(BuildContext context) => secondary;
  static Color background(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? backgroundDark : backgroundLight;
  static Color text(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? textDark : textLight;
  static Color errorColor(BuildContext context) => error;
  static Color successColor(BuildContext context) => success;
}
