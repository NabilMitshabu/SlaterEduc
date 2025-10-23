import 'package:flutter/material.dart';
import 'package:slatereduc/services/app_colors.dart';
import 'package:slatereduc/services/app_localizations.dart';

class ResultatCompletScreen extends StatefulWidget {
  const ResultatCompletScreen({super.key});

  @override
  State<ResultatCompletScreen> createState() => _ResultatCompletScreenState();
}

class _ResultatCompletScreenState extends State<ResultatCompletScreen> {
  int selectedIndex = 0;

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
    final loc = AppLocalizations.of(context);
    final bleu = AppColors.primary(context);
    final background = AppColors.background(context);
    final textColor = AppColors.text(context);

    final periodes = [loc.translate('period_1'), loc.translate('period_2'), loc.translate('period_3')];
    final resultats = resultatsParPeriode[periodes[selectedIndex]] ?? resultatsParPeriode.values.first;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: bleu),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          loc.translate('result_complete'),
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      backgroundColor: background,
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(periodes.length, (i) {
                      final selected = selectedIndex == i;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: selected ? bleu : background,
                            foregroundColor: selected ? Colors.white : bleu,
                            side: BorderSide(color: bleu, width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          onPressed: () => setState(() => selectedIndex = i),
                          child: Text(
                            periodes[i],
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 16),

                // Tableau principal des cours
                Container(
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.alpha(bleu, 0.18)),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.alpha(bleu, 0.04),
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
                      inside: BorderSide(color: AppColors.alpha(bleu, 0.12)),
                      outside: BorderSide(color: AppColors.alpha(bleu, 0.18)),
                    ),
                    children: [
                      TableRow(
                        decoration: BoxDecoration(color: AppColors.alpha(bleu, 0.08)),
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Center(
                              child: Text(
                                loc.translate('cours'),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Center(
                              child: Text(
                                loc.translate('points_obtenus'),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
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
                                style: TextStyle(fontSize: 15, color: textColor),
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
                                  color: bleu,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )),
                    ],
                  ),
                ),
                const SizedBox(height: 80),
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
                  padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  elevation: 2,
                ),
                icon: const Icon(Icons.download_rounded),
                label: Text(
                  loc.translate('download'),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(loc.translate('downloading'))),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEvaluationsSheet(
      BuildContext context, String cours, List<dynamic> evaluations) {
    final loc = AppLocalizations.of(context);
    final bleu = AppColors.primary(context);
    final background = AppColors.background(context);
    final textColor = AppColors.text(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: background,
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
                    color: Colors.grey[400],
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
                    border: Border.all(color: AppColors.alpha(bleu, 0.2)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Table(
                    columnWidths: const {
                      0: FlexColumnWidth(2),
                      1: FlexColumnWidth(2),
                      2: FlexColumnWidth(1),
                    },
                    border: TableBorder.symmetric(
                      inside: BorderSide(color: AppColors.alpha(bleu, 0.12)),
                    ),
                    children: [
                      TableRow(
                        decoration: BoxDecoration(color: AppColors.alpha(bleu, 0.08)),
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Center(
                              child: Text(
                                loc.translate('evaluation_type'),
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: textColor),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Center(
                              child: Text(
                                loc.translate('evaluation_date'),
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: textColor),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Center(
                              child: Text(
                                loc.translate('points'),
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: textColor),
                              ),
                            ),
                          ),
                        ],
                      ),
                      ...evaluations.map((e) => TableRow(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 4),
                            child:
                            Text(e["type"], style: TextStyle(color: textColor)),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 4),
                            child:
                            Text(e["date"], style: TextStyle(color: textColor)),
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
