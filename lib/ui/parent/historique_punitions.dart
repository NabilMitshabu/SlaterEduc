import 'package:flutter/material.dart';
import 'package:slatereduc/services/app_colors.dart';
import 'package:slatereduc/services/app_localizations.dart';
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
        "titre": "incomplete_notebook",
        "date": "12 Décembre 2024",
      },
      {
        "titre": "late_to_school",
        "date": "12 Décembre 2024",
      },
      {
        "titre": "class_disturbance",
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
          AppLocalizations.of(context).translate('history_punishments'),
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
                  AppLocalizations.of(context).translate(p["titre"]!),
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
                        description: AppLocalizations.of(context).translate('punition_description_' + p["titre"]!),
                        punition: AppLocalizations.of(context).translate('punition_action_' + p["titre"]!),
                        statut: AppLocalizations.of(context).translate('status_done'),
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
