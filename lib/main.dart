import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:slatereduc/routes/router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:slatereduc/services/theme_provider.dart';
import 'package:slatereduc/services/app_colors.dart';
import 'package:slatereduc/services/language_provider.dart';
import 'package:slatereduc/services/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR', null);

  // Initialisation synchrone du LanguageProvider avant runApp
  final languageProvider = await LanguageProvider.initialize();

  // Crée le router en écoutant les changements de langue pour forcer un refresh
  final router = createRouter(refreshListenable: languageProvider);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider.value(value: languageProvider),
      ],
      child: MyApp(router: router),
    ),
  );
}

class MyApp extends StatelessWidget {
  final GoRouter router;
  const MyApp({super.key, required this.router});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    return MaterialApp.router(
      routerConfig: router,
      title: 'Flutter Demo',
      locale: languageProvider.locale,
      localizationsDelegates: const [
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryBase,
          primary: AppColors.primaryBase,
          secondary: AppColors.accent,
          brightness: Brightness.light,
        ),
        brightness: Brightness.light,
        // Bottom navigation theme pour le thème clair
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: AppColors.surfaceLight,
          selectedItemColor: AppColors.primaryBase,
          unselectedItemColor: Colors.grey.shade600,
          selectedIconTheme: const IconThemeData(color: AppColors.primaryBase),
          unselectedIconTheme: IconThemeData(color: Colors.grey.shade600),
          showUnselectedLabels: true,
          elevation: 12,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryBase,
          primary: AppColors.primaryBase,
          secondary: AppColors.secondaryBase,
          brightness: Brightness.dark,
        ),
        brightness: Brightness.dark,
        // Bottom navigation theme pour le thème sombre
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: AppColors.surfaceDark,
          selectedItemColor: AppColors.primaryBase,
          unselectedItemColor: Colors.grey.shade300,
          selectedIconTheme: const IconThemeData(color: AppColors.primaryBase),
          unselectedIconTheme: IconThemeData(color: Colors.grey.shade300),
          showUnselectedLabels: true,
          elevation: 12,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      themeMode: themeProvider.themeMode,
      debugShowCheckedModeBanner: false,
    );
  }
}
