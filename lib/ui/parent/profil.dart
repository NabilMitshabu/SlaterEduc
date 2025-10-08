import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/app_colors.dart';
import '../../services/theme_provider.dart';

class ProfilTab extends StatefulWidget {
  const ProfilTab({Key? key}) : super(key: key);

  @override
  State<ProfilTab> createState() => _ProfilTabState();
}

class _ProfilTabState extends State<ProfilTab> {
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.themeMode == ThemeMode.dark;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Profil",
          style: TextStyle(
            color: AppColors.text(context),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () {},

            child: const Text(
              "Éditer le profil",
              style: TextStyle(color: Colors.blue),
            ),
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Column(
              children: const [
                CircleAvatar(
                  radius: 50,
                  backgroundImage: AssetImage('assets/images/img1.png'),
                ),
                SizedBox(height: 10),
                Text(
                  "Madame Da Corbeau",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text("21nov2021@protonmail.com"),
              ],
            ),
          ),
          const SizedBox(height: 30),
          const SectionTitle(title: "Général"),
          const ProfileOption(
            icon: Icons.settings,
            title: "Logique",
            trailing: Icon(Icons.arrow_forward_ios, size: 16),
          ),
          const SwitchOption(
            icon: Icons.notifications,
            title: "Notifications",
            value: true,
            onChanged: null, // À remplacer par une fonction si nécessaire
          ),
          SwitchOption(
            icon: Icons.dark_mode,
            title: "Mode sombre",
            value: isDarkMode,
            onChanged: (val) {
              themeProvider.setDarkMode(val);
            },
          ),
          const SizedBox(height: 20),
          const SectionTitle(title: "Général"),
          const ProfileOption(
            icon: Icons.help_outline,
            title: "FAQ",
            trailing: Icon(Icons.arrow_forward_ios, size: 16),
          ),
          const ProfileOption(
            icon: Icons.support_agent,
            title: "Aide et Support",
            trailing: Icon(Icons.arrow_forward_ios, size: 16),
          ),
          const ProfileOption(
            icon: Icons.logout,
            title: "Déconnexion",
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
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
      leading: Icon(icon, color: Colors.blue),
      title: Text(title),
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
      leading: Icon(icon, color: Colors.blue),
      title: Text(title),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: Colors.blue,
      ),
    );
  }
}