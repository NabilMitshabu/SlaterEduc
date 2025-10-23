import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:slatereduc/services/app_colors.dart';
import 'package:slatereduc/services/theme_provider.dart';
import 'package:slatereduc/services/app_localizations.dart';
import 'package:slatereduc/services/language_provider.dart';
import 'package:slatereduc/services/translation_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ProfilTab extends StatefulWidget {
  const ProfilTab({Key? key}) : super(key: key);

  @override
  State<ProfilTab> createState() => _ProfilTabState();
}

class _ProfilTabState extends State<ProfilTab> {
  final _secureStorage = const FlutterSecureStorage();
  // helper to show API key dialog
  Future<void> _showApiKeyDialog(BuildContext context, LanguageProvider languageProvider) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await _secureStorage.read(key: 'google_translate_api_key') ?? '';
    final controller = TextEditingController(text: existing);

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clé Google Translate'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Entrez la clé API'),
          obscureText: true,
        ),
        actions: [
          TextButton(
            onPressed: () async {
              // clear saved key
              await _secureStorage.delete(key: 'google_translate_api_key');
              // clear cached dynamic translations
              final lang = languageProvider.locale.languageCode;
              await prefs.remove('dyn_trans_$lang');
              AppLocalizations.setDynamicTranslations(lang, {});
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Clé supprimée')));
            },
            child: const Text('Effacer'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              final key = controller.text.trim();
              if (key.isEmpty) return;
              // await TranslationService.saveApiKey(key); // supprimé : la clé ne doit jamais être stockée côté app
              // try to fetch translations for current language
              final lang = languageProvider.locale.languageCode;
              final dyn = await TranslationService.fetchTranslations(lang);
              if (dyn.isNotEmpty) {
                AppLocalizations.setDynamicTranslations(lang, dyn);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Clé sauvegardée et traductions chargées')));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Clé sauvegardée (aucune traduction chargée)')));
              }
              Navigator.of(context).pop();
            },
            child: const Text('Sauver'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.themeMode == ThemeMode.dark;
    final loc = AppLocalizations.of(context);
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background(context),
        elevation: 0,
        title: Text(
          loc.translate('profile'),
          style: TextStyle(
            color: AppColors.text(context),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
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
                Text(
                  "Madame Da Corbeau",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.text(context)),
                ),
                Text(
                  "21nov2021@protonmail.com",
                  style: TextStyle(color: AppColors.alpha(AppColors.text(context), 0.75)),
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
            trailing: DropdownButton<String>(
              value: languageProvider.locale.languageCode,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(value: 'fr', child: Text('Français')),
                DropdownMenuItem(value: 'en', child: Text('English')),
                DropdownMenuItem(value: 'sw', child: Text('Kiswahili')),
              ],
              onChanged: (val) {
                if (val != null) {
                  languageProvider.setLanguage(val);
                }
              },
            ),
          ),

          const SizedBox(height: 12),
          // ListTile to configure Google Translate API key (masqué, non affiché)
          // ListTile(
          //   leading: Icon(Icons.vpn_key, color: AppColors.primary(context)),
          //   title: Text('Clé API traduction', style: TextStyle(color: AppColors.text(context))),
          //   trailing: ElevatedButton(
          //     style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary(context)),
          //     child: Text('Configurer', style: TextStyle(color: AppColors.onPrimary(context))),
          //     onPressed: () => _showApiKeyDialog(context, languageProvider),
          //   ),
          // ),

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