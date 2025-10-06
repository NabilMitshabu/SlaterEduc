import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:slatereduc/routes/router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:slatereduc/services/theme_provider.dart';
import 'package:slatereduc/services/app_colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // nécessaire pour l'await
  await initializeDateFormatting('fr_FR', null); // initialise le français
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
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
    return MaterialApp.router(
      routerConfig: router,
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryBase,
          primary: AppColors.primaryBase,
          secondary: AppColors.accent,
          brightness: Brightness.light,
        ),
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryBase,
          primary: AppColors.primaryBase,
          secondary: AppColors.secondary,
          brightness: Brightness.dark,
        ),
        brightness: Brightness.dark,
      ),
      themeMode: themeProvider.themeMode,
      debugShowCheckedModeBanner: false,
    );
  }
}
