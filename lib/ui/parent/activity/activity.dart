import 'package:flutter/material.dart';
import 'package:slatereduc/services/app_colors.dart';
import 'package:slatereduc/services/app_localizations.dart';

import 'activityDetail.dart';

class ActiviteTab extends StatelessWidget {
  final List<Map<String, dynamic>> eleves;
  const ActiviteTab({super.key, this.eleves = const []});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    final List<Map<String, dynamic>> displayEleves = eleves.isNotEmpty
        ? eleves
            .map((e) => {
                  'id': (e['id'] ?? e['id_eleve'] ?? ''),
                  'nom': ((e['first_name'] ?? '') + ' ' + (e['last_name'] ?? '')).trim(),
                  'classe': (e['classe'] ?? e['level'] ?? ''),
                  'imagePath': (e['image'] as String?) ?? 'assets/images/img1.png',
                })
            .toList()
        : [
            {
              'id': '',
              'nom': 'Aucun enfant',
              'classe': '',
              'imagePath': 'assets/images/img1.png',
            }
          ];

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: Text(
          loc.translate('activities'),
          style: TextStyle(
            color: AppColors.text(context),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.text(context)),
      ),
      body: ListView(
        children: displayEleves.map((eleve) {
          return Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.background(context), // couleur dynamique selon le mode
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        eleve["imagePath"]!,
                        width: 160,
                        height: 160,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Image.asset('assets/images/img1.png', width: 160, height: 160, fit: BoxFit.cover),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            eleve["nom"]!,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppColors.text(context), // texte dynamique
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            eleve["classe"]!,
                            style: TextStyle(
                              fontSize: 15,
                              color: AppColors.alpha(AppColors.text(context), 0.7), // texte dynamique
                            ),
                          ),
                          SizedBox(height: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              foregroundColor: AppColors.text(context),
                            ),
                            onPressed: () {
                              print('DEBUG: ActiviteTab - opening details for eleveId=${eleve["id"]} nom=${eleve["nom"]}');
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ActiviteDetailsScreen(
                                    nom: eleve["nom"]!,
                                    classe: eleve["classe"]!,
                                    imagePath: eleve["imagePath"]!,
                                    eleveId: (eleve["id"] ?? ''),
                                  ),
                                ),
                              );
                            },
                            child: Text(loc.translate('view_activities')),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
