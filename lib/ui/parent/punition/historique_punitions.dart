import 'package:flutter/material.dart';
import 'package:slatereduc/services/app_colors.dart';
import 'package:slatereduc/services/app_localizations.dart';
import 'package:slatereduc/services/api/historique_punitions_service.dart';
import '../paiement/historique_punition_detail.dart';

class HistoriquePunitionsScreen extends StatelessWidget {
  final String studentId;
  const HistoriquePunitionsScreen({super.key, required this.studentId});

  @override
  Widget build(BuildContext context) {
    final bleu = AppColors.primary(context);
    final textColor = AppColors.text(context);
    final background = AppColors.background(context);
    final service = HistoriquePunitionsService();

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
        child: FutureBuilder<List<Punition>>(
          future: service.fetchPunitions(studentId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator(color: bleu));
            }
            if (snapshot.hasError) {
              return Center(child: Text('Erreur: ${snapshot.error}', style: TextStyle(color: textColor)));
            }
            final punitions = snapshot.data ?? [];
            if (punitions.isEmpty) {
              return Center(child: Text(AppLocalizations.of(context).translate('no_punitions'), style: TextStyle(color: textColor)));
            }
            return ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: punitions.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final p = punitions[index];
                return Container(
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
                      p.motif,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: textColor,
                      ),
                    ),
                    subtitle: Text(
                      p.date.split('T').first,
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
                            titre: p.motif,
                            description: p.description,
                            punition: p.motif,
                            statut: p.status == 0 ? AppLocalizations.of(context).translate('status_done') : AppLocalizations.of(context).translate('status_pending'),
                            date: p.date.split('T').first,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
