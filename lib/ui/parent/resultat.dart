import 'package:flutter/material.dart';

class ResultatCompletScreen extends StatefulWidget {
  const ResultatCompletScreen({super.key});

  @override
  State<ResultatCompletScreen> createState() => _ResultatCompletScreenState();
}

class _ResultatCompletScreenState extends State<ResultatCompletScreen> {
  int selectedIndex = 0;

  final List<String> periodes = [
    "1ère Période",
    "2ème Période",
    "3ème Période",
  ];

  // Exemple de résultats par période
  final Map<String, List<Map<String, dynamic>>> resultatsParPeriode = {
    "1ère Période": [
      {
        "cours": "Mathématiques",
        "points": "14/20",
        "evaluations": [
          {"type": "Interrogation", "date": "Lundi 13 Sept. 2024", "points": "12/20"},
          {"type": "Travail Pratique", "date": "Lundi 15 Juin 2025", "points": "14/10"},
          {"type": "Travail Dirigé", "date": "Mardi 02 Juillet 2025", "points": "00/20"},
          {"type": "Devoir", "date": "Mardi 15 Juin 2025", "points": "02/10"},
        ],
      },
      {
        "cours": "Français",
        "points": "18/20",
        "evaluations": [
          {"type": "Interrogation", "date": "Lundi 01 Avril 2025", "points": "17/20"},
          {"type": "Devoir", "date": "Mardi 20 Avril 2025", "points": "19/20"},
        ],
      },
    ],
    "2ème Période": [
      {
        "cours": "Physique",
        "points": "15/20",
        "evaluations": [
          {"type": "Interrogation", "date": "Lundi 05 Mai 2025", "points": "14/20"},
          {"type": "Devoir", "date": "Mardi 10 Mai 2025", "points": "16/20"},
        ],
      },
    ],
    "3ème Période": [
      {
        "cours": "Anglais",
        "points": "16/20",
        "evaluations": [
          {"type": "Test oral", "date": "Vendredi 12 Sept. 2025", "points": "18/20"},
        ],
      },
    ],
  };

  @override
  Widget build(BuildContext context) {
    final bleu = const Color(0xFF1B54F5);
    final resultats = resultatsParPeriode[periodes[selectedIndex]] ?? [];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: bleu),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Résultat complet",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Column(
              children: [
                // Liste des périodes scrollable horizontalement
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(periodes.length, (i) {
                      final selected = selectedIndex == i;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: selected ? bleu : Colors.white,
                            foregroundColor: selected ? Colors.white : bleu,
                            side: BorderSide(color: bleu, width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          onPressed: () => setState(() => selectedIndex = i),
                          child: Text(periodes[i],
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 16),

                // Tableau principal des cours
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: bleu.withOpacity(0.18)),
                    boxShadow: [
                      BoxShadow(
                        color: bleu.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Table(
                    columnWidths: const {
                      0: FlexColumnWidth(2),
                      1: FlexColumnWidth(1),
                    },
                    border: TableBorder.symmetric(
                      inside: BorderSide(color: bleu.withOpacity(0.12)),
                      outside: BorderSide(color: bleu.withOpacity(0.18)),
                    ),
                    children: [
                      TableRow(
                        decoration: BoxDecoration(color: bleu.withOpacity(0.08)),
                        children: const [
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: Center(
                              child: Text("Cours",
                                  style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: Center(
                              child: Text("Points Obtenus",
                                  style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                      ...resultats.map((r) => TableRow(
                        children: [
                          GestureDetector(
                            onTap: () => _showEvaluationsSheet(
                                context, r["cours"], r["evaluations"]),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 4),
                              child: Text(
                                r["cours"],
                                style: const TextStyle(fontSize: 15),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 4),
                            child: Center(
                              child: Text(
                                r["points"],
                                style: TextStyle(
                                    color: bleu, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      )),
                    ],
                  ),
                ),
                const SizedBox(height: 80), // Pour laisser la place au bouton en bas
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: Center(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: bleu,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  elevation: 2,
                ),
                icon: const Icon(Icons.download_rounded),
                label: const Text('Télécharger', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                onPressed: () {
                  // TODO: Ajouter la logique de téléchargement du résultat
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Téléchargement en cours...')),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Fonction pour afficher la BottomSheet
  void _showEvaluationsSheet(
      BuildContext context, String cours, List<dynamic> evaluations) {
    final bleu = const Color(0xFF1B54F5);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  cours,
                  style: TextStyle(
                    fontSize: 18,
                    color: bleu,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: bleu.withOpacity(0.2)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Table(
                    columnWidths: const {
                      0: FlexColumnWidth(2),
                      1: FlexColumnWidth(2),
                      2: FlexColumnWidth(1),
                    },
                    border: TableBorder.symmetric(
                      inside: BorderSide(color: bleu.withOpacity(0.12)),
                    ),
                    children: [
                      TableRow(
                        decoration: BoxDecoration(color: bleu.withOpacity(0.08)),
                        children: const [
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: Center(
                              child: Text("Type d’évaluation",
                                  style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: Center(
                              child: Text("Date de l’évaluation",
                                  style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: Center(
                              child: Text("Points",
                                  style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                      ...evaluations.map((e) => TableRow(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 4),
                            child: Text(e["type"]),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 4),
                            child: Text(e["date"]),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 4),
                            child: Center(
                              child: Text(
                                e["points"],
                                style: TextStyle(
                                    color: bleu, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      )),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
