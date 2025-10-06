import 'package:flutter/material.dart';
import 'package:slatereduc/services/app_colors.dart';

import 'activityDetail.dart';

class ActiviteTab extends StatelessWidget {
  const ActiviteTab({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> eleves = [
      {
        "nom": "Ocean NTAMBWE",
        "classe": "4 ème Primaire",
        "imagePath": "assets/images/img1.png", // Remplace par une image existante
      },
      {
        "nom": "Lumière NTAMBWE",
        "classe": "6ème Commerciale et Gestion",
        "imagePath": "assets/images/img1.png", // Remplace par une image existante
      },
    ];

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: Text(
          "Activités",
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
        children: eleves.map((eleve) {
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
                              fontSize: 18,
                              color: AppColors.text(context), // texte dynamique
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            eleve["classe"]!,
                            style: TextStyle(
                              fontSize: 15,
                              color: AppColors.text(context).withOpacity(0.7), // texte dynamique
                            ),
                          ),
                          SizedBox(height: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              foregroundColor: AppColors.text(context),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ActiviteDetailsScreen(
                                    nom: eleve["nom"]!,
                                    classe: eleve["classe"]!,
                                    imagePath: eleve["imagePath"]!,
                                  ),
                                ),
                              );
                            },
                            child: Text("Voir les activités"),
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
