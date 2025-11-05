import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:slatereduc/services/app_colors.dart';
import 'package:slatereduc/services/theme_provider.dart';
import 'package:slatereduc/services/app_localizations.dart';
import 'package:slatereduc/services/language_provider.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slatereduc/services/parent_service.dart';

class ProfilTab extends StatefulWidget {
  const ProfilTab({Key? key}) : super(key: key);

  @override
  State<ProfilTab> createState() => _ProfilTabState();
}

class _ProfilTabState extends State<ProfilTab> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.themeMode == ThemeMode.dark;
    final loc = AppLocalizations.of(context);
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.background(context),

      appBar: AppBar(
        elevation: 0,
        title: Text(
          loc.translate('profile'),
          style: TextStyle(
            color: AppColors.text(context),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Column(
              children: [
                const CircleAvatar(
                  radius: 50,
                  backgroundImage: AssetImage('assets/images/img1.png'),
                ),
                const SizedBox(height: 10),
                // Remplacement du nom statique par le nom dynamique du parent
                FutureBuilder<Map<String, dynamic>>(
                  future: _getParentDataFromApi(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const CircularProgressIndicator();
                    }
                    final parent = snapshot.data;
                    final nom = parent != null ? ((parent['first_name'] ?? '') + ' ' + (parent['last_name'] ?? '')) : '';
                    final phone = parent != null ? (parent['phone'] ?? '') : '';
                    if (nom.trim().isEmpty) {
                      return Text('Nom du parent non trouvé', style: TextStyle(color: Colors.red));
                    }
                    return Column(
                      children: [
                        Text(
                          nom,
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.text(context)),
                        ),
                        Text(
                          phone,
                          style: TextStyle(color: AppColors.alpha(AppColors.text(context), 0.75)),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          SectionTitle(title: loc.translate('general')),
          ProfileOption(
            icon: Icons.settings,
            title: loc.translate('settings'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          ),
          SwitchOption(
            icon: Icons.notifications,
            title: loc.translate('notifications'),
            value: true,
            onChanged: null, // À remplacer par une fonction si nécessaire
          ),
          SwitchOption(
            icon: Icons.dark_mode,
            title: loc.translate('dark_mode'),
            value: isDarkMode,
            onChanged: (val) {
              themeProvider.setDarkMode(val);
            },
          ),

          const SizedBox(height: 20),
          // Option pour changer la langue
          ListTile(
            leading: Icon(Icons.language, color: AppColors.primary(context)),
            title: Text(loc.translate('language'), style: TextStyle(color: AppColors.text(context))),
            trailing: _isLoading
                ? const SizedBox(width: 48, height: 24, child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
                : DropdownButton<String>(
                    value: languageProvider.locale.languageCode,
                    underline: const SizedBox.shrink(),
                    items: [
                      DropdownMenuItem(value: 'fr', child: Text(loc.translate('french'))),
                      DropdownMenuItem(value: 'en', child: Text(loc.translate('english'))),
                      DropdownMenuItem(value: 'sw', child: Text(loc.translate('swahili'))),
                    ],
                    onChanged: (val) async {
                      if (val != null) {
                        setState(() { _isLoading = true; });
                        // change app language and let provider handle loading dynamic translations
                        final bool loaded = await languageProvider.setLanguage(val);
                        if (loaded) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.translate('translations_loaded'))));
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.translate('no_dynamic_translation_found'))));
                        }
                        setState(() { _isLoading = false; });
                      }
                    },
                  ),
          ),


          const SizedBox(height: 10),
          SectionTitle(title: loc.translate('general')),
          ProfileOption(
            icon: Icons.help_outline,
            title: loc.translate('faq'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          ),
          ProfileOption(
            icon: Icons.support_agent,
            title: loc.translate('help'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          ),
          ProfileOption(
            icon: Icons.logout,
            title: loc.translate('logout'),
            trailing: null,
          ),
        ],
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _getAllParents() async {
    final parentService = ParentService();
    final url = '${parentService.baseUrl}/parents';
    try {
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode == 200) {
        final body = json.decode(resp.body);
        if (body is List) {
          return List<Map<String, dynamic>>.from(body.map((e) => Map<String, dynamic>.from(e)));
        }
      }
    } catch (e) {
      print('Erreur getAllParents: $e');
    }
    return [];
  }

  // Méthode robuste pour récupérer le parent connecté
  Future<Map<String, dynamic>> _getParentDataFromApi() async {
    final prefs = await SharedPreferences.getInstance();
    String? userId;
    final jsonStr = prefs.getString('parent_data');
    if (jsonStr != null) {
      try {
        final parentData = Map<String, dynamic>.from(json.decode(jsonStr));
        userId = parentData['id_user']?.toString();
        if (userId == null && parentData['id'] != null) {
          userId = parentData['id'].toString();
        }
      } catch (_) {}
    }
    if (userId == null) {
      userId = prefs.getString('user_id');
    }
    final parentsList = await _getAllParents();
    if (userId != null && parentsList.isNotEmpty) {
      final found = parentsList.firstWhere(
        (p) => p['id_user']?.toString() == userId,
        orElse: () => <String, dynamic>{},
      );
      if (found.isNotEmpty) return found;
    }
    return {};
  }
}

class SectionTitle extends StatelessWidget {
  final String title;

  const SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.text(context)),
      ),
    );
  }
}

class ProfileOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;

  const ProfileOption({
    required this.icon,
    required this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary(context)),
      title: Text(title, style: TextStyle(color: AppColors.text(context))),
      trailing: trailing,
      onTap: () {},
    );
  }
}

class SwitchOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const SwitchOption({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary(context)),
      title: Text(title, style: TextStyle(color: AppColors.text(context))),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: AppColors.primary(context),
      ),
    );
  }
}