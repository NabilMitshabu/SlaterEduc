import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:slatereduc/services/app_colors.dart';
import 'historique_punitions.dart';
import 'resultat.dart';
import 'historique_paiement.dart';


class ActiviteDetailsScreen extends StatefulWidget {
  final String nom;
  final String classe;
  final String imagePath;

  const ActiviteDetailsScreen({
    super.key,
    required this.nom,
    required this.classe,
    required this.imagePath,
  });

  @override
  State<ActiviteDetailsScreen> createState() => _ActiviteDetailsScreenState();
}

class _ActiviteDetailsScreenState extends State<ActiviteDetailsScreen> {
  DateTime today = DateTime.now();
  bool showCalendar = false;

  @override
  Widget build(BuildContext context) {
    DateTime monday = today.subtract(Duration(days: today.weekday - 1));
    // Générer la semaine (lundi à vendredi)
    List<DateTime> weekdays =
    List.generate(5, (i) => monday.add(Duration(days: i)));

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Bouton retour
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            // Photo + infos de l’élève
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundImage: AssetImage(widget.imagePath),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.nom,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(
                  widget.classe,
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Mois + petit calendrier horizontal
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      showCalendar = !showCalendar;
                    });
                  },
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month, color: Colors.blue),
                      const SizedBox(width: 5),
                      Text(
                        DateFormat("MMMM yyyy").format(today),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Icon(
                        showCalendar ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                        color: Colors.blue,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Ligne horizontale avec lundi → vendredi
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: weekdays.map((day) {
                    bool isSelected = DateFormat("yyyy-MM-dd").format(day) ==
                        DateFormat("yyyy-MM-dd").format(today);
                    return _buildDayBox(
                      DateFormat("E", "fr_FR").format(day), // ex: Lun, Mar
                      DateFormat("dd").format(day), // ex: 09
                      isSelected,
                    );
                  }).toList(),
                ),

                // Calendrier complet (masqué/affiché)
                if (showCalendar)
                  CalendarDatePicker(
                    initialDate: today,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                    onDateChanged: (date) {
                      setState(() {
                        today = date;
                      });
                    },
                  ),
              ],
            ),

            const SizedBox(height: 20),

            // Solde de frais
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    const Text("Solde de Frais", style: TextStyle(fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.history, color: Colors.blue),
                      tooltip: 'Historique paiement',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const HistoriquePaiementScreen()),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text("250"),
                    Text("900"),
                  ],
                ),
                const SizedBox(height: 5),
                LinearProgressIndicator(
                  value: 250 / 900,
                  color: Colors.blue,
                  backgroundColor: Colors.grey[300],
                ),
              ],
            ),

            const SizedBox(height: 30),

            // ---- Ligne + Texte "PREMIER DEMESTRE" + Ligne ----
            Row(
              children: const [
                Expanded(child: Divider(thickness: 1)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    "PREMIER DEMESTRE",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                Expanded(child: Divider(thickness: 1)),
              ],
            ),

            const SizedBox(height: 20),

            // Bloc des statistiques
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: const [
                      Column(
                        children: [
                          Text("87%", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue)),
                          Text("POURCENTAGE"),
                        ],
                      ),
                      Column(
                        children: [
                          Text("01", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue)),
                          Text("PLACE"),
                        ],
                      ),
                      Column(
                        children: [
                          Text("E", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue)),
                          Text("MENTION"),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ResultatCompletScreen()),
                      );
                    },
                    child: const Text("Résultat complet"),
                  )
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Discipline
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Discipline", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.gavel, color: Colors.blue, size: 40),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text("Barème de sanction", style: TextStyle(fontWeight: FontWeight.bold)),
                            Text("L’élève NTAMBWE a reçu une note en Conduite"),
                          ],
                        ),
                      ),
                      const Text("75%", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 18)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(

              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const HistoriquePunitionsScreen()),
                );
              },
              child: const Text("Historique des activités"),
            )
          ],
        ),
      ),
    );
  }

  // --- Widget pour afficher un jour (comme sur l'image) ---
  Widget _buildDayBox(String day, String date, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: isSelected ? Colors.blue : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue),
      ),
      child: Column(
        children: [
          Text(day, style: TextStyle(color: isSelected ? Colors.white : Colors.blue)),
          const SizedBox(height: 4),
          Text(date, style: TextStyle(color: isSelected ? Colors.white : Colors.blue, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
