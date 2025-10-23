import 'package:flutter/material.dart';
import 'package:slatereduc/services/app_colors.dart';
import 'historique_punition_detail.dart';

class HistoriquePunitionsScreen extends StatelessWidget {
  const HistoriquePunitionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bleu = AppColors.primary(context);
    final textColor = AppColors.text(context);
    final background = AppColors.background(context);

    final punitions = [
      {
        "titre": "Cahier incomplet",
        "date": "12 Décembre 2024",
      },
      {
        "titre": "Retard à l'école",
        "date": "12 Décembre 2024",
      },
      {
        "titre": "Perturbation des cours",
        "date": "12 Décembre 2024",
      },
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Historique de punitions",
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      backgroundColor: background,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            ...punitions.map((p) => Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.alpha(bleu, 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.alpha(bleu, 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.edit_note, color: bleu, size: 28),
                ),
                title: Text(
                  p["titre"]!,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: textColor,
                  ),
                ),
                subtitle: Text(
                  p["date"]!,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                  ),
                ),
                trailing: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.alpha(bleu, 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.arrow_forward_ios, color: bleu, size: 20),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => HistoriquePunitionDetailScreen(
                        titre: p["titre"]!,
                        description: p["titre"] == "Cahier incomplet"
                            ? "Le cahier de l’élève n’est pas complètement rempli. Il manque la leçon sur l’histoire."
                            : p["titre"] == "Retard à l'école"
                            ? "L’élève est arrivé après la sonnerie."
                            : "L’élève a perturbé la classe pendant la leçon.",
                        punition: p["titre"] == "Cahier incomplet"
                            ? "L’élève est collé et doit rester jusqu’à 15h pour finir la leçon manquante."
                            : p["titre"] == "Retard à l'école"
                            ? "L’élève doit présenter une excuse écrite."
                            : "L’élève doit présenter ses excuses à la classe.",
                        statut: "Effectué",
                        date: p["date"]!,
                      ),
                    ),
                  );
                },
              ),
            )),
          ],
        ),
      ),
    );
  }
}
