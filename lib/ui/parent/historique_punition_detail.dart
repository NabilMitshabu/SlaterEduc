import 'package:flutter/material.dart';
import 'package:slatereduc/services/app_colors.dart';
import 'package:slatereduc/services/app_localizations.dart';

class HistoriquePunitionDetailScreen extends StatelessWidget {
  final String titre;
  final String description;
  final String punition;
  final String statut;
  final String date;

  const HistoriquePunitionDetailScreen({
    super.key,
    required this.titre,
    required this.description,
    required this.punition,
    required this.statut,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    final bleu = AppColors.primary(context);
    final textColor = AppColors.text(context);
    final background = AppColors.background(context);
    final loc = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          loc.translate('details'),
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      backgroundColor: background,
      body: SingleChildScrollView(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppColors.alpha(bleu, 0.08),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Center(
                  child: Text(
                    titre,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: textColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              const Divider(height: 2, thickness: 2, color: Color(0xFFD9E8FF)),

              const SizedBox(height: 18),
              _buildRow(loc.translate('description'), description, textColor),
              _buildRow(loc.translate('punitions'), punition, textColor),
              _buildRowStatut(loc.translate('punition_status'), statut, bleu, textColor),
              _buildRow(loc.translate('date_label'), date, textColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                    color: textColor,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: AppColors.alpha(Colors.grey, 0.75),
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1.5, color: Color(0xFFD9E8FF)),
      ],
    );
  }

  Widget _buildRowStatut(String label, String statut, Color bleu, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                    color: textColor,
                  ),
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.alpha(bleu, 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statut,
                  style: TextStyle(
                    color: bleu,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const Divider(height: 1, thickness: 1.5, color: Color(0xFFD9E8FF)),

            ],
          ),
        ),
        const Divider(height: 1.5, thickness: 1.5, color: Color(0xFFD9E8FF)),
      ],
    );
  }
}
