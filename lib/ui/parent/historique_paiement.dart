import 'package:flutter/material.dart';
import '../../services/app_colors.dart';

class HistoriquePaiementScreen extends StatelessWidget {
  const HistoriquePaiementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bleu = AppColors.primary(context);
    final bg = AppColors.background(context);
    final txt = AppColors.text(context);
    final paiements = [
      {
        "regle": "Minerval Septembre",
        "date": "Lundi 13 Sept.2024",
        "somme": "70",
      },
      {
        "regle": "Frais de l'etat",
        "date": "Lundi 15 Juin 2025",
        "somme": "20",
      },
      {
        "regle": "Frais des examens",
        "date": "Mardi 02 Juillet 2025",
        "somme": "10",
      },
      {
        "regle": "Sortie vers Mikembo",
        "date": "Mardi 15 Juin 2025",
        "somme": "20",
      },
      {
        "regle": "Manifestations",
        "date": "Mardi 15 Juin 2025",
        "somme": "10",
      },
    ];
    return Scaffold(
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: txt),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Historique paiement",
          style: TextStyle(color: txt, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      backgroundColor: bg,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(2),
            1: FlexColumnWidth(2),
            2: FlexColumnWidth(1),
          },
          border: TableBorder.all(color: AppColors.alpha(bleu, 0.12)),
          children: [
            TableRow(
              decoration: BoxDecoration(color: AppColors.alpha(bleu, 0.08)),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Center(
                    child: Text("En règle de", style: TextStyle(fontWeight: FontWeight.bold, color: txt)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Center(
                    child: Text("Date de paiement", style: TextStyle(fontWeight: FontWeight.bold, color: txt)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Center(
                    child: Text("Sommes", style: TextStyle(fontWeight: FontWeight.bold, color: txt)),
                  ),
                ),
              ],
            ),
            ...paiements.map((p) => TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(p["regle"]!, style: TextStyle(color: txt)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(p["date"]!, style: TextStyle(color: txt)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Center(child: Text(p["somme"]!, style: TextStyle(color: bleu, fontWeight: FontWeight.bold))),
                ),
              ],
            )),
          ],
        ),
      ),
    );
  }
}
