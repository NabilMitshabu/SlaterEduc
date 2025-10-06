import 'package:flutter/material.dart';

class HistoriquePaiementScreen extends StatelessWidget {
  const HistoriquePaiementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bleu = const Color(0xFF1B54F5);
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
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Historique paiement",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(2),
            1: FlexColumnWidth(2),
            2: FlexColumnWidth(1),
          },
          border: TableBorder.all(color: bleu.withOpacity(0.12)),
          children: [
            TableRow(
              decoration: BoxDecoration(color: bleu.withOpacity(0.08)),
              children: const [
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Center(
                    child: Text("En règle de", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Center(
                    child: Text("Date de paiement", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Center(
                    child: Text("Sommes", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            ...paiements.map((p) => TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(p["regle"]!),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(p["date"]!),
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

